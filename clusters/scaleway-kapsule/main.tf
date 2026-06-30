resource "scaleway_k8s_cluster" "sandbox" {
  name    = var.cluster_name
  type    = "kapsule"
  version = var.scaleway_kubernetes_version
  cni     = var.scaleway_kapscule_cni

  delete_additional_resources = true

  private_network_id = scaleway_vpc_private_network.sandbox.id

  auto_upgrade {
    enable                        = true
    maintenance_window_start_hour = 1
    maintenance_window_day        = "any"
  }
}

resource "scaleway_vpc_private_network" "sandbox" {
  name   = var.cluster_name
  vpc_id = var.vpc_id
  ipv4_subnet {
    subnet = var.private_network_subnet
  }

  ipv6_subnets {
    subnet = var.private_network_ipv6_subnet
  }
  tags = ["sandbox", "kubernetes-workshops"]
}

resource "scaleway_k8s_pool" "pool" {
  cluster_id = scaleway_k8s_cluster.sandbox.id
  name       = "node_pool-${var.scaleway_kubernetes_pool_node_type}"

  zone      = var.scaleway_zone
  node_type = var.scaleway_kubernetes_pool_node_type
  size      = 1

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

  default_issuer_name = "letsencrypt-production"

  cluster_issuers = [
    {
      name                   = "letsencrypt-production"
      server                 = "https://acme-v02.api.letsencrypt.org/directory"
      private_key_secret_ref = "letsencrypt-production"
      solvers = [
        {
          http01 = {
            gatewayHTTPRoute = {
              parentRefs = [
                {
                  name      = "traefik-gateway"
                  namespace = "traefik"
                }
              ]
            }
          }
        }
      ]
    },
    {
      name                   = "letsencrypt-staging"
      server                 = "https://acme-staging-v02.api.letsencrypt.org/directory"
      private_key_secret_ref = "letsencrypt-staging"
      solvers = [
        {
          http01 = {
            gatewayHTTPRoute = {
              parentRefs = [
                {
                  name      = "traefik-gateway"
                  namespace = "traefik"
                }
              ]
            }
          }
        }
      ]
    }
  ]

  depends_on = [helm_release.gateway_api_crds]
}

module "grafana" {
  count            = var.enable_monitoring ? 1 : 0
  source           = "../modules/prometheus-grafana"
  base_domain_name = local.ingress_domain_name

  depends_on = [helm_release.traefik]
}

resource "helm_release" "crossplane" {
  count            = var.enable_crossplane ? 1 : 0
  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  version          = "1.16.0"
  namespace        = "crossplane-system"
  create_namespace = true
  wait             = true
}

resource "helm_release" "argocd" {
  count            = var.enable_argocd ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.3.7"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
}

resource "helm_release" "fluxcd" {
  count            = var.enable_fluxcd ? 1 : 0
  name             = "flux2"
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  version          = "2.18.4"
  namespace        = "flux-system"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    installCRDs = true
  })]
}




