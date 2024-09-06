output "kubeconfig" {
  value     = module.aks.kube_config_raw
  sensitive = true
}

output "grafana_host" {
  description = "Grafana hostname"
  value       = "https://${module.grafana.grafana_host}"
}

output "grafana_user" {
  description = "Grafana admin user"
  value       = module.grafana.grafana_user
}

output "grafana_password" {
  description = "Grafana password"
  value       = module.grafana.grafana_password
  sensitive = true
}
