# install prometheus+grafana with helm
resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

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
        "adminUser" : "admin",
        "ingress" : {
          "enabled" : true,
          "annotations" : {
            "kubernetes.io/ingress.class" : "nginx",
            "cert-manager.io/cluster-issuer" : "letsencrypt-production",
          },
          "hosts" : [
            "grafana.${local.ingress_domain_name}",
          ],
          "tls" : [
            {
              "secretName" : "grafana-tls",
              "hosts" : [
                "grafana.${local.ingress_domain_name}"
              ]
            }
          ]
        },
      }
    })
  ]

  # Below are the sensitive values that we don't want to be stored in the state file
  set {
    name  = "grafana.adminPassword"
    value = "${random_password.grafana_password.result}"
  }
}

# random password for grafana
resource "random_password" "grafana_password" {
  length  = 16
  special = false
}
