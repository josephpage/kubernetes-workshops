resource "scaleway_lb_ip" "gateway_ip" {
  zone       = var.scaleway_zone
  project_id = scaleway_k8s_cluster.sandbox.project_id
}



resource "helm_release" "gateway_api_crds" {
  name       = "gateway-api-crds"
  repository = "https://wiremind.github.io/wiremind-helm-charts"
  chart      = "gateway-api-crds"
  version    = "1.5.1"

  replace      = true
  force_update = true
}

resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true
  # cert-manager doit rester en place tant que Traefik existe : la Gateway référence
  # `cert-manager.io/cluster-issuer`, donc cert-manager crée des Certificate/Challenge liés à la
  # Gateway, avec leurs propres finalizers. Sans cette dépendance, Terraform peut détruire
  # cert-manager avant Traefik ; son contrôleur n'est alors plus là pour lever les finalizers, et
  # l'uninstall de Traefik reste bloqué en attente jusqu'au timeout Helm.
  depends_on = [helm_release.gateway_api_crds, module.cert-manager]

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Service Traefik supprime. Attente de la liberation de IP par le Load Balancer...' && sleep 60"
  }


  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "40.2.0"

  values = [yamlencode({
    deployment = {
      kind = "DaemonSet"
    }
    ingressClass = {
      enabled        = true
      isDefaultClass = true
    }
    ports = {
      web = {
        proxyProtocol = {
          trustedIPs = ["127.0.0.1/32", "192.168.0.0/16", "10.0.0.0/8"]
        }
        forwardedHeaders = {
          trustedIPs = ["127.0.0.1/32", "192.168.0.0/16", "10.0.0.0/8"]
        }
      }
      websecure = {
        proxyProtocol = {
          trustedIPs = ["127.0.0.1/32", "192.168.0.0/16", "10.0.0.0/8"]
        }
        forwardedHeaders = {
          trustedIPs = ["127.0.0.1/32", "192.168.0.0/16", "10.0.0.0/8"]
        }
      }
    }
    providers = {
      kubernetesIngress = {
        enabled = true
      }
      kubernetesGateway = {
        enabled = true
      }
    }
    gateway = {
      enabled = true
      name    = "traefik-gateway"
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-production"
      }
      listeners = {
        web = {
          port     = 8000 # Container port for 'web'
          protocol = "HTTP"
          namespacePolicy = {
            from = "All"
          }
        }
        websecure = {
          port     = 8443 # Container port for 'websecure'
          protocol = "HTTPS"
          hostname = local.ingress_domain_name
          namespacePolicy = {
            from = "All"
          }
          certificateRefs = [
            {
              name = "gateway-tls"
            }
          ]
        }
        grafana = {
          port     = 8443 # Container port for 'websecure'
          protocol = "HTTPS"
          hostname = "grafana.${local.ingress_domain_name}"
          namespacePolicy = {
            from = "All"
          }
          certificateRefs = [
            {
              name = "gateway-tls"
            }
          ]
        }
      }
    }
    service = {
      type = "LoadBalancer"
      annotations = {
        "service.beta.kubernetes.io/scw-loadbalancer-proxy-protocol-v2"        = "true"
        "service.beta.kubernetes.io/scw-loadbalancer-zone"                     = scaleway_lb_ip.gateway_ip.zone
        "service.beta.kubernetes.io/scw-loadbalancer-use-hostname"             = "true"
        "service.beta.kubernetes.io/scw-loadbalancer-redispatch-attempt-count" = "1"
        "service.beta.kubernetes.io/scw-loadbalancer-max-retries"              = "5"
      }
      spec = {
        loadBalancerIP = scaleway_lb_ip.gateway_ip.ip_address
      }
    }
  })]
}

locals {
  ingress_domain_name = "${replace(scaleway_lb_ip.gateway_ip.ip_address, ".", "-")}.${var.magic_xip_domain}"
}
