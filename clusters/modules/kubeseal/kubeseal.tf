# helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets

resource "helm_release" "kubeseal" {
    name             = "kubeseal"
    namespace        = "kubeseal"
    create_namespace = true
    
    repository = "https://bitnami-labs.github.io/sealed-secrets"
    chart      = "sealed-secrets"
    
    values = [yamlencode({})]
}
