output "wildcard_dns_of_the_nodes" {
  value = scaleway_k8s_cluster.sandbox.wildcard_dns
}

output "load_balancer_ip" {
  value = scaleway_lb_ip.gateway_ip.ip_address
}

output "kubeconfig_file" {
  value = local_sensitive_file.kubeconfig.filename
}

output "grafana_url" {
  value = var.enable_monitoring ? "https://grafana.${local.ingress_domain_name}" : null
}

output "grafana_admin_password" {
  value     = var.enable_monitoring ? module.grafana[0].grafana_password : null
  sensitive = true
}

output "k8s_host" {
  value       = null_resource.kubeconfig.triggers.host
  description = "L'adresse API de connexion au cluster Kubernetes"
}

output "k8s_token" {
  value       = null_resource.kubeconfig.triggers.token
  sensitive   = true
  description = "Le token de connexion administrateur au cluster"
}

output "k8s_cluster_ca_certificate" {
  value       = null_resource.kubeconfig.triggers.cluster_ca_certificate
  sensitive   = true
  description = "Le certificat d'autorité de certification (CA) du cluster"
}

