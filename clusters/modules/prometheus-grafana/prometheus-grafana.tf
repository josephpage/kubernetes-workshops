locals {
  grafana_user     = "admin"
  grafana_password = sensitive(random_password.grafana_password.result)
  grafana_host     = "grafana.${var.base_domain_name}"
}

# install prometheus+grafana with helm
resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "87.10.1"

  values = [yamlencode(
    {
      "alertmanager" : {
        "enabled" : true,
      },
      "server" : {
        "persistentVolume" : {
          "enabled" : true,
          "size" : "100Gi",
        },
        "retention" : "7d",
      },
      "nodeExporter" : {
        "enabled" : true,
      },
      "kubeStateMetrics" : {
        "enabled" : true,
      },
      "grafana" : {
        "enabled" : true,
        "persistence" : {
          "enabled" : true,
          "size" : "10Gi",
          "accessModes" : [
            "ReadWriteOnce",
          ],
        },
        "service" : {
          "type" : "ClusterIP",
        },
        "adminUser" : local.grafana_user,
        "ingress" : {
          "enabled" : false,
        },
        "route" : {
          "main" : {
            "enabled" : true,
            "parentRefs" : [
              {
                "name" : "traefik-gateway",
                "namespace" : "traefik",
              }
            ],
            "hostnames" : [
              local.grafana_host,
            ],
          },
        },
      }
    })
  ]



  # Below are the sensitive values that we don't want to be stored in the state file
  set = [
    {
      name  = "grafana.adminPassword"
      value = local.grafana_password
    }
  ]
}

# random password for grafana
resource "random_password" "grafana_password" {
  length  = 16
  special = false
}
