resource "scaleway_lb_ip" "nginx_ip" {
  zone       = var.scaleway_zone
  project_id = scaleway_k8s_cluster.sandbox.project_id
}

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  namespace        = "nginx-ingress"
  create_namespace = true

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  values = [yamlencode(
    {
      controller = {
        service = {
          type                  = "LoadBalancer"
          loadBalancerIP        = scaleway_lb_ip.nginx_ip.ip_address
          externalTrafficPolicy = "Local"
          annotations = {
            "service.beta.kubernetes.io/scw-loadbalancer-proxy-protocol-v2"        = true
            "service.beta.kubernetes.io/scw-loadbalancer-zone"                     = scaleway_lb_ip.nginx_ip.zone
            "service.beta.kubernetes.io/scw-loadbalancer-use-hostname"             = true
            "service.beta.kubernetes.io/scw-loadbalancer-redispatch-attempt-count" = 1
            "service.beta.kubernetes.io/scw-loadbalancer-max-retries"              = 5
          }
        }
        config = {
          use-forwarded-headers = "true"
          use-proxy-protocol    = "true"
        }
      }
    }
  )]
}

locals {
  ingress_domain_name = "${replace(scaleway_lb_ip.nginx_ip.ip_address, ".", "-")}.sslip.io"
}
