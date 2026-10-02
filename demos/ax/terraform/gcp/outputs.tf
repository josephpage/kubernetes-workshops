output "kubeconfig_file" {
  value       = local_sensitive_file.kubeconfig.filename
  description = "Kubeconfig du cluster (authentification par gke-gcloud-auth-plugin)."
}

output "workshop_env_file" {
  value       = abspath(local_sensitive_file.workshop_env.filename)
  description = "Fichier à sourcer avant de lancer les scripts de l'atelier."
}

output "registry_login" {
  value       = "gcloud auth configure-docker ${var.region}-docker.pkg.dev"
  description = "Commande d'authentification Docker/ko à Artifact Registry."
}

output "snapshots_bucket" {
  value       = google_storage_bucket.snapshots.name
  description = "Bucket GCS des snapshots des sandboxes."
}
