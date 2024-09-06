resource "scaleway_k8s_cluster" "sandbox" {
  name    = "sandbox-cluster"
  type    = "kapsule"
  version = var.scaleway_kubernetes_version
  cni     = var.scaleway_kapscule_cni

  delete_additional_resources = true

  auto_upgrade {
    enable                        = true
    maintenance_window_start_hour = 1
    maintenance_window_day        = "any"
  }
}

resource "scaleway_k8s_pool" "pool" {
  cluster_id = scaleway_k8s_cluster.sandbox.id
  name       = "node_pool-${var.scaleway_kubernetes_pool_node_type}"
  node_type  = var.scaleway_kubernetes_pool_node_type
  size       = 1

  min_size    = 1
  max_size    = 10
  autoscaling = true
  autohealing = true

  wait_for_pool_ready = true
}

resource "null_resource" "kubeconfig" {
  depends_on = [scaleway_k8s_pool.pool] # at least one pool here
  triggers = {
    host                   = scaleway_k8s_cluster.sandbox.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.sandbox.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.sandbox.kubeconfig[0].cluster_ca_certificate
  }
}

resource "local_sensitive_file" "kubeconfig" {
  depends_on = [null_resource.kubeconfig]
  content    = scaleway_k8s_cluster.sandbox.kubeconfig[0].config_file
  filename   = pathexpand("~/.kube/kubeconfig-${scaleway_k8s_cluster.sandbox.name}")
}

# resource "scaleway_instance_security_group" "sg" {
#   name                    = "kubernetes-${scaleway_k8s_cluster.sandbox.name}-sg"
#   inbound_default_policy  = "accept" # By default we accept all outgoing traffic
#   outbound_default_policy = "accept" # By default we accept all outgoing traffic

#   outbound_rule {
#     action   = "drop"
#     port     = 25
#     ip_range = "0.0.0.0/0"
#     protocol = "TCP"
#   }

#   outbound_rule {
#     action   = "drop"
#     port     = 25
#     ip_range = "::/0"
#     protocol = "TCP"
#   }

#   outbound_rule {
#     action   = "drop"
#     port     = 465
#     ip_range = "0.0.0.0/0"
#     protocol = "TCP"
#   }

#   outbound_rule {
#     action   = "drop"
#     port     = 465
#     ip_range = "::/0"
#     protocol = "TCP"
#   }

#   outbound_rule {
#     action   = "drop"
#     port     = 587
#     ip_range = "0.0.0.0/0"
#     protocol = "TCP"
#   }

#   outbound_rule {
#     action   = "drop"
#     port     = 587
#     ip_range = "::/0"
#     protocol = "TCP"
#   }
# }

module "cert-manager" {
  source = "../modules/cert-manager"
  email = "jopa@octo.com"
}

module "grafana" {
  source = "../modules/prometheus-grafana"
  base_domain_name = local.ingress_domain_name
}
