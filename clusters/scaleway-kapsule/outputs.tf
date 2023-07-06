output "wildcard_dns_of_the_nodes" {
  value = scaleway_k8s_cluster.sandbox.wildcard_dns
}

output "load_balancer_ip" {
  value = scaleway_lb_ip.nginx_ip.ip_address
}

output "kubeconfig_file" {
  value = local_sensitive_file.kubeconfig.filename
}

output "grafana_url" {
  value = "https://grafana.${local.ingress_domain_name}"
}

output "grafana_admin_password" {
  value     = random_password.grafana_password.result
  sensitive = true
}
