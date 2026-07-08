variable "cluster_issuers" {
  type = list(object({
    name                   = string
    server                 = string
    private_key_secret_ref = optional(string)
    solvers                = list(any)
  }))

  description = "ClusterIssuers to create with the certmanager-letsencrypt chart."
}

variable "default_issuer_name" {
  type        = string
  description = "Default ClusterIssuer name configured in cert-manager ingressShim."
  default     = "letsencrypt-production"
}
