terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.74.0"
    }
    random = {
      source = "hashicorp/random"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
  required_version = "~> 1.4"
}

provider "scaleway" {
  # Les credentials seront récupérés automatiquement depuis les variables d'environnement
  # SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID
}

provider "helm" {
  alias = "platform"
  kubernetes = {
    host                   = module.platform_cluster.k8s_host
    token                  = module.platform_cluster.k8s_token
    cluster_ca_certificate = base64decode(module.platform_cluster.k8s_cluster_ca_certificate)
  }
}

provider "kubernetes" {
  alias                  = "platform"
  host                   = module.platform_cluster.k8s_host
  token                  = module.platform_cluster.k8s_token
  cluster_ca_certificate = base64decode(module.platform_cluster.k8s_cluster_ca_certificate)
}

provider "helm" {
  alias = "worker"
  kubernetes = {
    host                   = module.worker_cluster.k8s_host
    token                  = module.worker_cluster.k8s_token
    cluster_ca_certificate = base64decode(module.worker_cluster.k8s_cluster_ca_certificate)
  }
}

provider "kubernetes" {
  alias                  = "worker"
  host                   = module.worker_cluster.k8s_host
  token                  = module.worker_cluster.k8s_token
  cluster_ca_certificate = base64decode(module.worker_cluster.k8s_cluster_ca_certificate)
}
