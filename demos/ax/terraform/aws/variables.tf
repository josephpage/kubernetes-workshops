variable "region" {
  type        = string
  default     = "eu-west-3"
  description = "Région AWS du cluster, des registres privés et du bucket de snapshots."
}

variable "cluster_name" {
  type        = string
  default     = "ax-workshop"
  description = "Nom du cluster EKS ; sert aussi de préfixe aux autres ressources."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.37"
  description = "Version Kubernetes. Agent Substrate exige 1.37+ ; EKS ne permet pas d'activer les APIs bêta de la 1.36."

  validation {
    condition     = can(regex("^1\\.(3[7-9]|[4-9][0-9])$", var.kubernetes_version))
    error_message = "Agent Substrate exige Kubernetes 1.37 ou plus (format attendu : 1.37)."
  }
}

variable "instance_type" {
  type        = string
  default     = "m6i.xlarge"
  description = "Type d'instance des nœuds : x86_64, 4 vCPU / 16 Gio minimum."
}

variable "node_count" {
  type        = number
  default     = 2
  description = "Nombre de nœuds (taille fixe)."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.42.0.0/16"
  description = "Plage d'adresses du VPC dédié à l'atelier."
}

variable "bedrock_region" {
  type        = string
  default     = "eu-west-3"
  description = "Région Bedrock appelée par la passerelle LLM."
}

variable "llm_model" {
  type        = string
  default     = "anthropic.claude-opus-5-5"
  description = "Identifiant de modèle Bedrock (ou de profil d'inférence) utilisé par l'agent, sans le préfixe bedrock/."
}
