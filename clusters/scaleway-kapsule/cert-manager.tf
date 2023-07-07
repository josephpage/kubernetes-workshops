# install cert-manager with helm
resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  values = [yamlencode(
    {
      installCRDs = true
      ingressShim = {
        defaultIssuerName: "letsencrypt-production"
        defaultIssuerKind: "ClusterIssuer"
      }
    }
  )]
}

resource "helm_release" "letsencrypt-issuer" {
  for_each = toset(["production", "staging"])

  name             = "letsencrypt-clusterissuer-${each.key}"
  namespace        = "cert-manager"

  repository = "https://radar-base.github.io/radar-helm-charts"
  chart      = "cert-manager-letsencrypt"

  values = [yamlencode(
    {
      nameOverride = "letsencrypt-${each.key}"
      fullnameOverride = "letsencrypt-${each.key}"
      maintainerEmail = "jopa@octo.com"
      httpIssuer = {
        environment = each.key
        privateSecretRef = "clusterissuer-letsencrypt-${each.key}"
      }
    }
  )]

  depends_on = [ helm_release.cert-manager ]
}
