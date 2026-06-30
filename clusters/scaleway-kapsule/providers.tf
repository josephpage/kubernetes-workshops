terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.74.0"
    }

    null   = "~> 3.2.3"
    random = "~> 3.6.3"
    local  = "~> 2.5.2"
    helm   = "~> 3.1.1"
  }

  required_version = "~> 1.4"
}

provider "helm" {
  kubernetes = {
    host                   = null_resource.kubeconfig.triggers.host
    token                  = null_resource.kubeconfig.triggers.token
    cluster_ca_certificate = base64decode(null_resource.kubeconfig.triggers.cluster_ca_certificate)
  }
}
