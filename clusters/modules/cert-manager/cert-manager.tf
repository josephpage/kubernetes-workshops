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
        defaultIssuerName : var.default_issuer_name
        defaultIssuerKind : "ClusterIssuer"
      }
      config = {
        apiVersion       = "controller.config.cert-manager.io/v1alpha1"
        kind             = "ControllerConfiguration"
        enableGatewayAPI = true
      }
    }
  )]
}

resource "helm_release" "letsencrypt-issuers" {
  name      = "letsencrypt-issuers"
  namespace = "cert-manager"

  repository = "https://charts.somaz.blog"
  chart      = "certmanager-letsencrypt"
  version    = "0.2.2"

  values = [yamlencode({
    clusterIssuers = [
      for issuer in var.cluster_issuers : {
        name                = issuer.name
        email               = coalesce(var.email, "noreply@example.com")
        server              = issuer.server
        privateKeySecretRef = coalesce(issuer.private_key_secret_ref, issuer.name)
        solvers             = issuer.solvers
      }
    ]
  })]

  depends_on = [helm_release.cert-manager]
}
