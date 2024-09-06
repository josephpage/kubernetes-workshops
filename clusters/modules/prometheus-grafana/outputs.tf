output "grafana_host" {
    description = "Grafana hostname"
    value = local.grafana_host
}

output "grafana_user" {
    description = "Grafana admin user"
    value = local.grafana_user
}

output "grafana_password" {
  description = "Grafana admin password"
  value = random_password.grafana_password.result
}
