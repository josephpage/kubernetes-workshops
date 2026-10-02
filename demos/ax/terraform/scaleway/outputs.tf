output "kubeconfig_file" {
  value       = local_sensitive_file.kubeconfig.filename
  description = "Kubeconfig du cluster (aussi exporté par workshop.env)."
}

output "workshop_env_file" {
  value       = abspath(local_sensitive_file.workshop_env.filename)
  description = "Fichier à sourcer avant de lancer les scripts de l'atelier."
}

output "registry_login" {
  value       = "echo \"$SCW_SECRET_KEY\" | docker login ${scaleway_registry_namespace.this.endpoint} -u nologin --password-stdin"
  description = "Commande d'authentification Docker/ko au registre de session."
}

output "snapshots_bucket" {
  value       = scaleway_object_bucket.snapshots.name
  description = "Bucket Object Storage des snapshots des sandboxes."
}
