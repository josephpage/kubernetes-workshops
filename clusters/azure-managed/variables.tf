variable "create_resource_group" {
  type     = bool
  default  = false
  nullable = false
}

variable "location" {
  default = "francecentral"
}

variable "resource_group_name" {
  type    = string
  default = null
}

variable "magic_xip_domain" {
  default = "sslip.io"
}

variable "use_arm64_nodes" {
  description = "Use ARM64 nodes instead of x86. Default is false."
  type    = bool
  default = false
}
