resource "scaleway_vpc" "kratix_vpc" {
  name = "kratix-workshop-vpc"
}

module "platform_cluster" {
  source = "../../../clusters/scaleway-kapsule"

  cluster_name                = "kratix-platform"
  vpc_id                      = scaleway_vpc.kratix_vpc.id
  enable_crossplane           = false
  enable_argocd               = false
  scaleway_project_id         = var.scaleway_project_id
  scaleway_region             = var.scaleway_region
  scaleway_zone               = var.scaleway_zone
  private_network_subnet      = "172.16.20.0/22"
  private_network_ipv6_subnet = "fd48:84f2:7301:6c38::/64"
}

module "worker_cluster" {
  source = "../../../clusters/scaleway-kapsule"

  cluster_name                = "kratix-worker"
  vpc_id                      = scaleway_vpc.kratix_vpc.id
  enable_crossplane           = true
  enable_argocd               = false
  enable_fluxcd               = true
  enable_monitoring           = false
  scaleway_project_id         = var.scaleway_project_id
  scaleway_region             = var.scaleway_region
  scaleway_zone               = var.scaleway_zone
  private_network_subnet      = "172.16.24.0/22"
  private_network_ipv6_subnet = "fd48:84f2:7301:6c39::/64"
}

# Création explicite du namespace pour Kratix sur le cluster Platform
resource "kubernetes_namespace_v1" "kratix_platform_system" {
  provider   = kubernetes.platform
  depends_on = [module.platform_cluster]
  metadata {
    name = "kratix-platform-system"

    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }

    annotations = {
      # `release-namespace` doit correspondre au namespace DE LA RELEASE helm_release.kratix
      # (celui où Helm stocke son Secret de suivi, ici "default"), pas au nom de ce namespace
      # applicatif lui-même — sinon Helm refuse d'adopter cet objet pré-existant ("invalid
      # ownership metadata").
      "meta.helm.sh/release-name"      = "kratix"
      "meta.helm.sh/release-namespace" = "default"
    }
  }

  lifecycle {
    # Helm ajoute ses propres labels à ce namespace après adoption (app.kubernetes.io/instance,
    # control-plane, etc.) : on ignore les labels pour ne pas les effacer sur un futur apply, mais
    # PAS les annotations (release-name/release-namespace ci-dessus doivent rester gérées par nous).
    ignore_changes = [metadata[0].labels]
  }
}

# Installation spécifique de Kratix sur le cluster Platform (pour cet atelier)
#
# Le chart kratix hardcode `kratix-platform-system` dans absolument toutes ses ressources
# (y compris son propre manifeste Namespace), quel que soit le namespace passé ici. Or Helm stocke
# le Secret de suivi de la release dans CE namespace (le champ `namespace` ci-dessous) : si on le
# fait correspondre au namespace que le chart supprime lui-même à la désinstallation, la suppression
# du namespace entraîne avec elle le Secret de release avant que Helm ait pu le purger proprement
# (erreur "Failed to purge the release: release: not found"). En pointant `namespace` vers "default"
# (qui n'est jamais supprimé), le Secret de suivi de la release est totalement découplé du sort du
# namespace applicatif "kratix-platform-system" — les ressources du chart continuent d'aller dans ce
# dernier (hardcodé par le chart), mais la suppression de ce namespace n'affecte plus la release.
resource "helm_release" "kratix" {
  provider         = helm.platform
  name             = "kratix"
  repository       = "https://syntasso.github.io/helm-charts"
  chart            = "kratix"
  namespace        = "default"
  create_namespace = false
  wait             = true

  # On s'assure que le namespace et le module de base (cert-manager) ont bien terminé
  depends_on = [module.platform_cluster, kubernetes_namespace_v1.kratix_platform_system]
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "scaleway_object_bucket" "kratix_state_store" {
  name          = "kratix-state-store-${random_id.bucket_suffix.hex}"
  region        = var.scaleway_region
  force_destroy = true
}

# Secret contenant les credentials Scaleway pour que Kratix puisse écrire sur S3
resource "kubernetes_secret_v1" "scaleway_s3_credentials" {
  provider = kubernetes.platform

  metadata {
    name      = "scaleway-s3-credentials"
    namespace = "default"
  }

  data = {
    accessKeyID     = var.scaleway_access_key
    secretAccessKey = var.scaleway_secret_key
  }

  depends_on = [module.platform_cluster]
}

# Secret contenant les credentials S3 de Scaleway pour FluxCD sur le cluster Worker
resource "kubernetes_secret_v1" "scaleway_s3_credentials_flux" {
  provider = kubernetes.worker

  metadata {
    name      = "scaleway-s3-credentials-flux"
    namespace = "flux-system"
  }

  data = {
    accesskey = var.scaleway_access_key
    secretkey = var.scaleway_secret_key
  }

  depends_on = [module.worker_cluster]
}

# Secret contenant les clés API Scaleway pour Crossplane sur le cluster Worker
resource "kubernetes_secret_v1" "scaleway_creds" {
  provider = kubernetes.worker

  metadata {
    name      = "scaleway-creds"
    namespace = "crossplane-system"
  }

  data = {
    credentials = jsonencode({
      access_key = var.scaleway_access_key
      secret_key = var.scaleway_secret_key
      project_id = var.scaleway_project_id != null ? var.scaleway_project_id : ""
    })
  }

  depends_on = [module.worker_cluster]
}

# Installation et configuration du Provider Scaleway pour Crossplane
resource "null_resource" "crossplane_scaleway_provider" {
  triggers = {
    worker_kubeconfig = module.worker_cluster.kubeconfig_file
  }

  provisioner "local-exec" {
    command = <<EOT
      set -eu

      KUBECTL="kubectl --kubeconfig=${module.worker_cluster.kubeconfig_file}"

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
    module.worker_cluster,
    kubernetes_secret_v1.scaleway_creds
  ]
}
