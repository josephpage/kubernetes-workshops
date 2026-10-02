variable "region" {
  type        = string
  default     = "fr-par"
  description = "Région Scaleway (cluster, registre, Object Storage)."
}

variable "zone" {
  type        = string
  default     = "fr-par-2"
  description = "Zone du pool de nœuds (fr-par-2 : la plus sobre énergétiquement de la région)."
}

variable "cluster_name" {
  type        = string
  default     = "ax-workshop"
  description = "Nom du cluster Kapsule ; sert aussi de préfixe aux autres ressources."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.37.0"
  description = "Version Kubernetes. Agent Substrate exige 1.37+ (PodCertificateRequest et ClusterTrustBundle GA)."

  validation {
    condition     = can(regex("^1\\.(3[7-9]|[4-9][0-9])(\\.[0-9]+)?$", var.kubernetes_version))
    error_message = "Agent Substrate exige Kubernetes 1.37 ou plus."
  }
}

variable "node_type" {
  type        = string
  default     = "PRO2-XS"
  description = "Type d'instance des nœuds : x86_64, 4 vCPU / 16 Go minimum (control plane Substrate + workers gVisor + agents)."
}

variable "node_count" {
  type        = number
  default     = 2
  description = "Nombre de nœuds (taille fixe : pas d'autoscaling, voir main.tf)."
}

variable "llm_model" {
  type        = string
  default     = "qwen3-coder-30b-a3b-instruct"
  description = "Modèle Scaleway Generative APIs utilisé par l'agent (doit savoir appeler des outils)."
}
