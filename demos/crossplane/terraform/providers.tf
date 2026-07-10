terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.74.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source = "hashicorp/random"
    }
    local = {
      source = "hashicorp/local"
    }
  }
  required_version = "~> 1.4"
}

provider "scaleway" {
  # Les credentials seront récupérés automatiquement depuis les variables d'environnement
  # SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID
}

provider "kubernetes" {
  host                   = module.cluster.k8s_host
  token                  = module.cluster.k8s_token
  cluster_ca_certificate = base64decode(module.cluster.k8s_cluster_ca_certificate)
}
