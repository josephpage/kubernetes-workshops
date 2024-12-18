terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.48.0"
    }

    null   = "~> 3.2.3"
    random = "~> 3.6.3"
    local  = "~> 2.5.2"
    helm   = "~> 2.16.1"
  }

  required_version = "~> 1.4"
}

provider "scaleway" {}

provider "helm" {
  kubernetes {
    host                   = null_resource.kubeconfig.triggers.host
    token                  = null_resource.kubeconfig.triggers.token
    cluster_ca_certificate = base64decode(null_resource.kubeconfig.triggers.cluster_ca_certificate)
  }
}
