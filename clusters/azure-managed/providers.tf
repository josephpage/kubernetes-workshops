terraform {
  required_version = ">=1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.51, < 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.3.2"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "random" {}

provider "helm" {
  kubernetes {
    host                   = yamldecode(module.aks.kube_config_raw).clusters[0].cluster.server
    token                  = yamldecode(module.aks.kube_config_raw).users[0].user.token
    client_certificate     = base64decode(yamldecode(module.aks.kube_config_raw).users[0].user["client-certificate-data"])
    client_key             = base64decode(yamldecode(module.aks.kube_config_raw).users[0].user["client-key-data"])
    cluster_ca_certificate = base64decode(yamldecode(module.aks.kube_config_raw).clusters[0].cluster["certificate-authority-data"])
  }
}
