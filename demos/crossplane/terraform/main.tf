resource "scaleway_vpc" "crossplane_vpc" {
  name = "crossplane-workshop-vpc"
}

# Namespace de registre dédié à CETTE session : public (le package manager de
# Crossplane tire les images sans imagePullSecret) mais individuel et détruit avec
# le reste de l'infrastructure par `tofu destroy` — pas de ressource cloud partagée
# qui survivrait à l'atelier.
resource "random_id" "registry_suffix" {
  byte_length = 4
}

resource "scaleway_registry_namespace" "functions" {
  name      = "crossplane-workshop-${random_id.registry_suffix.hex}"
  is_public = true
  region    = var.scaleway_region
}

# Un seul cluster : contrairement à l'atelier Kratix (platform + worker synchronisés via S3),
# Crossplane est à la fois le control plane ET l'endroit où les ressources composées atterrissent.
module "cluster" {
  source = "../../../clusters/scaleway-kapsule"

  cluster_name                = "crossplane-workshop"
  vpc_id                      = scaleway_vpc.crossplane_vpc.id
  enable_crossplane           = true
  crossplane_version          = var.crossplane_version
  # Operations (Operation, CronOperation, WatchOperation) est une feature alpha
  # de Crossplane 2.x, requise pour l'exercice 4 (day-2).
  crossplane_args             = ["--enable-operations"]
  enable_argocd               = false
  enable_fluxcd               = false
  enable_monitoring           = false
  scaleway_project_id         = var.scaleway_project_id
  scaleway_region             = var.scaleway_region
  scaleway_zone               = var.scaleway_zone
  private_network_subnet      = "172.16.28.0/22"
  private_network_ipv6_subnet = "fd48:84f2:7301:6c3a::/64"
}

# Secret contenant les clés API Scaleway pour le Provider Scaleway de Crossplane
resource "kubernetes_secret_v1" "scaleway_creds" {
  metadata {
    name      = "scaleway-creds"
    namespace = "crossplane-system"
  }

  data = {
    credentials = jsonencode({
      access_key = var.scaleway_access_key
      secret_key = var.scaleway_secret_key
      project_id = var.scaleway_project_id
    })
  }

  lifecycle {
    # Contrairement au provider Terraform, le Provider Scaleway de Crossplane ne lit
    # PAS SCW_DEFAULT_PROJECT_ID : un project_id vide fait échouer la création des
    # ressources RDB avec "At least project_id is required".
    precondition {
      condition     = var.scaleway_project_id != null && var.scaleway_project_id != ""
      error_message = "scaleway_project_id est requis (passez -var=\"scaleway_project_id=$SCW_DEFAULT_PROJECT_ID\")."
    }
  }

  depends_on = [module.cluster]
}

# Installation et configuration du Provider Scaleway pour Crossplane
resource "null_resource" "crossplane_scaleway_provider" {
  triggers = {
    kubeconfig = module.cluster.kubeconfig_file
  }

  provisioner "local-exec" {
    command = <<EOT
      set -eu

      KUBECTL="kubectl --kubeconfig=${module.cluster.kubeconfig_file}"

      # Attend qu'un CRD existe puis que son status.conditions signale Established.
      # Bornée pour éviter une boucle infinie en cas de vrai problème (~4 min max par CRD).
      wait_for_crd_established() {
        crd_name="$1"
        max_attempts=24

        echo "Attente de la création du CRD $crd_name..."
        attempt=0
        until $KUBECTL get crd "$crd_name" >/dev/null 2>&1; do
          attempt=$((attempt + 1))
          if [ "$attempt" -ge "$max_attempts" ]; then
            echo "Erreur: le CRD $crd_name n'a pas été créé après $max_attempts tentatives" >&2
            exit 1
          fi
          sleep 5
        done

        # On lit directement status.conditions plutôt que d'utiliser `kubectl wait
        # --for=condition=`, qui échoue systématiquement (timeout) sur ces CRDs avec
        # certaines combinaisons de versions client/serveur alors que la condition
        # est bien à `True` (vérifié manuellement).
        echo "Attente de l'établissement (status.conditions) du CRD $crd_name..."
        attempt=0
        until [ "$($KUBECTL get crd "$crd_name" -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null)" = "True" ]; do
          attempt=$((attempt + 1))
          if [ "$attempt" -ge "$max_attempts" ]; then
            echo "Erreur: le CRD $crd_name n'a jamais atteint l'état Established" >&2
            exit 1
          fi
          sleep 5
        done
      }

      # 1. CRD Provider de Crossplane (déjà garanti par helm_release.crossplane wait=true,
      #    mais on applique le même contrôle par cohérence et robustesse).
      wait_for_crd_established "providers.pkg.crossplane.io"

      # 2. Déployer le Provider Scaleway de Crossplane
      $KUBECTL apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-scaleway
spec:
  package: xpkg.upbound.io/scaleway/provider-scaleway:v0.6.0
EOF

      # 3. CRD ProviderConfig installé par le contrôleur du Provider Scaleway
      wait_for_crd_established "providerconfigs.scaleway.upbound.io"

      # 4. Configurer le ProviderConfig par défaut, avec retry pour couvrir un léger
      #    délai de propagation dans l'aggregation layer juste après l'établissement du CRD.
      attempt=0
      max_attempts=12
      until $KUBECTL apply -f - <<EOF >/dev/null 2>&1
apiVersion: scaleway.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: scaleway-creds
      key: credentials
EOF
      do
        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$max_attempts" ]; then
          echo "Erreur: impossible d'appliquer le ProviderConfig scaleway.upbound.io/default après $max_attempts tentatives" >&2
          exit 1
        fi
        sleep 5
      done

      echo "Provider et ProviderConfig Scaleway configurés avec succès."
    EOT
  }

  depends_on = [
    module.cluster,
    kubernetes_secret_v1.scaleway_creds
  ]
}

# Rendu du manifeste des Functions avec le registre individuel de cette session.
# Les 2 Functions custom (ticket-gate, namespace-secret) restent HEALTHY=False tant
# que leurs images n'ont pas été poussées (cf. README, étape 1) : Crossplane retente
# le pull automatiquement, aucune ré-application n'est nécessaire ensuite.
resource "local_file" "platform_functions_rendered" {
  filename = "${path.module}/../platform/functions.rendered.yaml"
  content = templatefile("${path.module}/../platform/functions.yaml.tpl", {
    registry = scaleway_registry_namespace.functions.endpoint
  })
}

resource "null_resource" "platform_functions" {
  triggers = {
    rendered_sha = local_file.platform_functions_rendered.content_sha256
    kubeconfig   = module.cluster.kubeconfig_file
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig=${module.cluster.kubeconfig_file} apply -f ${local_file.platform_functions_rendered.filename}"
  }

  depends_on = [
    module.cluster,
    local_file.platform_functions_rendered,
  ]
}
