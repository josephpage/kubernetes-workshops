output "kubeconfig_file" {
  value       = local_sensitive_file.kubeconfig.filename
  description = "Kubeconfig du cluster."
}

output "workshop_env_file" {
  value       = abspath(local_sensitive_file.workshop_env.filename)
  description = "Fichier à sourcer avant de lancer les scripts de l'atelier."
}

output "registry_login" {
  value       = "az acr login --name ${azurerm_container_registry.this.name}"
  description = "Commande d'authentification Docker/ko à Azure Container Registry."
}
