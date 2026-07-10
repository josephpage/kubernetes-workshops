variable "scaleway_organization_id" {
  default = null
}

variable "scaleway_project_id" {
  default = null
}

variable "scaleway_region" {
  default = "fr-par"
}

variable "scaleway_zone" {
  # The default is the most energy-efficient zone for the Paris region
  default = "fr-par-2"
}

variable "cluster_name" {
  default = "sandbox-cluster"
}

variable "scaleway_kapscule_cni" {
  default = "cilium"
}

variable "scaleway_kubernetes_version" {
  default = "1.35"
}

variable "scaleway_kubernetes_pool_node_type" {
  default = "DEV1-M"
}

variable "magic_xip_domain" {
  default = "sslip.io"
}

variable "enable_crossplane" {
  type        = bool
  default     = false
  description = "Installer Crossplane sur le cluster"
}

variable "crossplane_version" {
  type        = string
  default     = "1.16.0"
  description = "Version du chart Helm Crossplane (le défaut préserve les ateliers existants)"
}

variable "enable_argocd" {
  type        = bool
  default     = false
  description = "Installer ArgoCD sur le cluster"
}

variable "private_network_subnet" {
  type        = string
  default     = "172.16.20.0/22"
  description = "Plage d'adresses IP privées (CIDR) pour le réseau privé du cluster"
}

variable "private_network_ipv6_subnet" {
  type        = string
  default     = "fd48:84f2:7301:6c38::/64"
  description = "Plage d'adresses IPv6 privées pour le réseau privé du cluster"
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "ID du VPC dans lequel créer le réseau privé (si non spécifié, utilise le VPC par défaut du projet)"
}

variable "enable_fluxcd" {
  type        = bool
  default     = false
  description = "Installer FluxCD sur le cluster"
}

variable "enable_monitoring" {
  type        = bool
  default     = true
  description = "Installer kube-prometheus-stack + Grafana sur le cluster"
}






