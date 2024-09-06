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

variable "scaleway_kapscule_cni" {
  default = "cilium"
}

variable "scaleway_kubernetes_version" {
  default = "1.30"
}

variable "scaleway_kubernetes_pool_node_type" {
  default = "DEV1-M"
}

variable "magic_xip_domain" {
  default = "sslip.io"
}
