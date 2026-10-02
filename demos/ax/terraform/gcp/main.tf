# Infrastructure de l'atelier AX sur Google Cloud :
# - un cluster GKE Standard 1.37 (canal RAPID, GKE Dataplane V2, Workload Identity) ;
# - un dépôt Artifact Registry (images Substrate, AX et des sandboxes) ;
# - un bucket GCS pour les snapshots : c'est la configuration native de Substrate
#   (backend gcs), sans composant « portable-s3 » ;
# - l'accès à Vertex AI (Gemini) pour la passerelle LLM.
#
# Les ServiceAccounts Kubernetes sont désignés directement comme principaux IAM
# (Workload Identity Federation for GKE) : aucun compte de service Google à
# emprunter, aucune clé.

resource "random_id" "suffix" {
  byte_length = 3
}

data "google_project" "this" {}

locals {
  suffix = random_id.suffix.hex
  # principal://.../subject/ns/<namespace>/sa/<serviceaccount>
  wi_principal = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject"
  atelet       = "${local.wi_principal}/ns/ate-system/sa/atelet"
  ate_api      = "${local.wi_principal}/ns/ate-system/sa/ate-api-server"
  litellm      = "${local.wi_principal}/ns/llm-gateway/sa/litellm"
}

resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "aiplatform.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

# --- Cluster -------------------------------------------------------------------

resource "google_service_account" "nodes" {
  account_id   = "${var.cluster_name}-nodes-${local.suffix}"
  display_name = "Nœuds GKE de l'atelier AX"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  name                = var.cluster_name
  location            = var.zone
  deletion_protection = false

  # 1.37 n'est disponible que dans le canal RAPID (octobre 2026). Les canaux
  # imposent la mise à jour automatique des nœuds : la fenêtre de maintenance
  # ci-dessous la repousse au dimanche matin.
  release_channel {
    channel = "RAPID"
  }
  min_master_version = var.kubernetes_version

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode   = "VPC_NATIVE"
  datapath_provider = "ADVANCED_DATAPATH" # GKE Dataplane V2 : applique les NetworkPolicy
  ip_allocation_policy {}

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  maintenance_policy {
    recurring_window {
      start_time = "2026-01-04T02:00:00Z"
      end_time   = "2026-01-04T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_container_node_pool" "workers" {
  name       = "ax-workers"
  cluster    = google_container_cluster.this.id
  location   = var.zone
  node_count = var.node_count

  management {
    auto_repair  = true
    auto_upgrade = true # imposé par le canal de release
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    spot            = false # un worker préempté fait perdre l'état des sandboxes
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "local_sensitive_file" "kubeconfig" {
  filename        = pathexpand("~/.kube/kubeconfig-${var.cluster_name}")
  file_permission = "0600"
  content = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = var.cluster_name
    clusters = [{
      name = var.cluster_name
      cluster = {
        server                     = "https://${google_container_cluster.this.endpoint}"
        certificate-authority-data = google_container_cluster.this.master_auth[0].cluster_ca_certificate
      }
    }]
    contexts = [{
      name    = var.cluster_name
      context = { cluster = var.cluster_name, user = var.cluster_name }
    }]
    users = [{
      name = var.cluster_name
      user = {
        exec = {
          apiVersion         = "client.authentication.k8s.io/v1beta1"
          command            = "gke-gcloud-auth-plugin"
          provideClusterInfo = true
        }
      }
    }]
  })
  depends_on = [google_container_node_pool.workers]
}

# --- Registre -------------------------------------------------------------------

resource "google_artifact_registry_repository" "this" {
  repository_id = "${var.cluster_name}-${local.suffix}"
  location      = var.region
  format        = "DOCKER"
  description   = "Images de l'atelier AX (Substrate, AX, sandboxes)"
  depends_on    = [google_project_service.apis]
}

# atelet tire l'image des sandboxes avec sa propre identité (--gcp-auth-for-image-pulls).
resource "google_artifact_registry_repository_iam_member" "atelet" {
  repository = google_artifact_registry_repository.this.name
  location   = var.region
  role       = "roles/artifactregistry.reader"
  member     = local.atelet
}

# --- Snapshots des sandboxes -----------------------------------------------------

resource "google_storage_bucket" "snapshots" {
  name                        = "${var.cluster_name}-snapshots-${local.suffix}"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "google_storage_bucket_iam_member" "snapshots" {
  for_each = {
    "atelet-admin"   = { member = local.atelet, role = "roles/storage.objectAdmin" }
    "atelet-viewer"  = { member = local.atelet, role = "roles/storage.bucketViewer" }
    "ate-api-admin"  = { member = local.ate_api, role = "roles/storage.objectAdmin" }
    "ate-api-viewer" = { member = local.ate_api, role = "roles/storage.bucketViewer" }
  }
  bucket = google_storage_bucket.snapshots.name
  role   = each.value.role
  member = each.value.member
}

# --- Passerelle LLM : Vertex AI -------------------------------------------------------

resource "google_project_iam_member" "litellm_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = local.litellm
}

# --- Contrat commun avec les scripts ------------------------------------------------

resource "local_sensitive_file" "workshop_env" {
  filename        = "${path.module}/../../workshop.env"
  file_permission = "0600"
  content = templatefile("${path.module}/../workshop.env.tftpl", {
    cloud        = "gcp"
    cluster_name = var.cluster_name
    kubeconfig   = local_sensitive_file.kubeconfig.filename

    image_repo       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
    agent_image_repo = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}/ax-agent-runner"

    snapshot_backend     = "gcs"
    snapshot_location    = "gs://${google_storage_bucket.snapshots.name}/ax"
    s3_endpoint          = ""
    s3_region            = ""
    s3_force_path_style  = "false"
    s3_access_key_id     = ""
    s3_secret_access_key = ""
    s3_in_cluster        = "false"

    llm_provider                   = "gcp"
    llm_model                      = var.llm_model
    llm_api_base                   = ""
    llm_api_key                    = "" # Workload Identity
    llm_api_version                = ""
    llm_aws_region                 = ""
    llm_vertex_project             = var.project_id
    llm_vertex_location            = var.llm_location
    llm_service_account_annotation = ""
  })
}
