# Infrastructure de l'atelier AX sur Scaleway :
# - un cluster Kapsule 1.37 (2 nœuds x86_64, taille fixe, sans mise à jour automatique) ;
# - un namespace Container Registry public (images Substrate, AX et des sandboxes) ;
# - un bucket Object Storage pour les snapshots des sandboxes ;
# - une application IAM dédiée, aux droits minimaux, dont la clé est remise au
#   cluster (snapshots S3 + Generative APIs) : on ne confie pas la clé personnelle
#   du participant au cluster.
#
# Toutes les sorties utiles aux scripts sont écrites dans demos/ax/workshop.env.

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  suffix     = random_id.suffix.hex
  project_id = scaleway_k8s_cluster.this.project_id
  tags       = ["kubernetes-workshops", "ax-workshop"]
}

resource "scaleway_vpc" "this" {
  name = var.cluster_name
  tags = local.tags
}

resource "scaleway_vpc_private_network" "this" {
  name   = var.cluster_name
  vpc_id = scaleway_vpc.this.id
  tags   = local.tags
}

resource "scaleway_k8s_cluster" "this" {
  name                        = var.cluster_name
  type                        = "kapsule"
  version                     = var.kubernetes_version
  cni                         = "cilium"
  private_network_id          = scaleway_vpc_private_network.this.id
  delete_additional_resources = true
  tags                        = local.tags

  # Substrate : un worker supprimé pendant une mise à jour de nœud fait perdre
  # l'état des sandboxes qui ne sont pas suspendues à temps. Pas de mise à jour
  # automatique pendant un atelier.
  auto_upgrade {
    enable                        = false
    maintenance_window_start_hour = 3
    maintenance_window_day        = "sunday"
  }
}

resource "scaleway_k8s_pool" "workers" {
  cluster_id = scaleway_k8s_cluster.this.id
  name       = "ax-workers"
  zone       = var.zone
  node_type  = var.node_type
  size       = var.node_count

  # Taille fixe : l'installeur Substrate pose le label ate.dev/substrate-version
  # sur les nœuds présents au moment de l'installation ; un nœud ajouté plus tard
  # par l'autoscaler n'hébergerait aucun worker.
  autoscaling            = false
  autohealing            = true
  root_volume_size_in_gb = 50
  wait_for_pool_ready    = true
  tags                   = local.tags
}

resource "local_sensitive_file" "kubeconfig" {
  depends_on      = [scaleway_k8s_pool.workers]
  content         = scaleway_k8s_cluster.this.kubeconfig[0].config_file
  filename        = pathexpand("~/.kube/kubeconfig-${var.cluster_name}")
  file_permission = "0600"
}

# Registre de session, public : atelet (Substrate) tire l'image des sandboxes
# sans identifiants. Détruit avec le reste par `tofu destroy`.
resource "scaleway_registry_namespace" "this" {
  name      = "${var.cluster_name}-${local.suffix}"
  region    = var.region
  is_public = true
}

# Snapshots des sandboxes (état de /workspace à chaque suspend).
resource "scaleway_object_bucket" "snapshots" {
  name          = "${var.cluster_name}-snapshots-${local.suffix}"
  region        = var.region
  force_destroy = true
  tags = {
    usage = "ax-workshop-snapshots"
  }
}

# Identité du cluster : lecture/écriture des snapshots et appels aux Generative APIs.
resource "scaleway_iam_application" "cluster" {
  name        = "${var.cluster_name}-${local.suffix}"
  description = "Atelier AX : snapshots Substrate et passerelle LLM du cluster ${var.cluster_name}"
  tags        = local.tags
}

resource "scaleway_iam_policy" "cluster" {
  name           = "${var.cluster_name}-${local.suffix}"
  description    = "Droits minimaux du cluster de l'atelier AX"
  application_id = scaleway_iam_application.cluster.id

  rule {
    project_ids = [local.project_id]
    permission_set_names = [
      "ObjectStorageBucketsRead",
      "ObjectStorageObjectsRead",
      "ObjectStorageObjectsWrite",
      "ObjectStorageObjectsDelete",
      "GenerativeApisModelAccess",
    ]
  }
}

resource "scaleway_iam_api_key" "cluster" {
  application_id     = scaleway_iam_application.cluster.id
  default_project_id = local.project_id
  description        = "Clé du cluster ${var.cluster_name} (atelier AX)"
}

resource "local_sensitive_file" "workshop_env" {
  filename        = "${path.module}/../../workshop.env"
  file_permission = "0600"
  content = templatefile("${path.module}/../workshop.env.tftpl", {
    cloud        = "scaleway"
    cluster_name = var.cluster_name
    kubeconfig   = local_sensitive_file.kubeconfig.filename

    image_repo       = scaleway_registry_namespace.this.endpoint
    agent_image_repo = "${scaleway_registry_namespace.this.endpoint}/ax-agent-runner"

    snapshot_backend     = "s3"
    snapshot_location    = "gs://${scaleway_object_bucket.snapshots.name}/ax"
    s3_endpoint          = "https://s3.${var.region}.scw.cloud"
    s3_region            = var.region
    s3_force_path_style  = "true"
    s3_access_key_id     = scaleway_iam_api_key.cluster.access_key
    s3_secret_access_key = scaleway_iam_api_key.cluster.secret_key
    s3_in_cluster        = "false"

    llm_provider                   = "scaleway"
    llm_model                      = var.llm_model
    llm_api_base                   = "https://api.scaleway.ai/${local.project_id}/v1"
    llm_api_key                    = scaleway_iam_api_key.cluster.secret_key
    llm_api_version                = ""
    llm_aws_region                 = ""
    llm_vertex_project             = ""
    llm_vertex_location            = ""
    llm_service_account_annotation = ""
  })
}
