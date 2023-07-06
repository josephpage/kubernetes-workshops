terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.18.0"
    }

    null       = "~> 3.2.0"
    random     = "~> 3.5.1"
    local      = "~> 2.4.0"
    helm       = "~> 2.10.1"
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
