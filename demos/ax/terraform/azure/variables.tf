variable "location" {
  type        = string
  default     = "francecentral"
  description = "Région Azure du cluster et du registre."
}

variable "cluster_name" {
  type        = string
  default     = "ax-workshop"
  description = "Nom du cluster AKS ; sert aussi de préfixe aux autres ressources."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.37"
  description = "Version Kubernetes. Agent Substrate exige 1.37+ (en preview sur AKS début octobre 2026 : vérifier avec az aks get-versions)."

  validation {
    condition     = can(regex("^1\\.(3[7-9]|[4-9][0-9])", var.kubernetes_version))
    error_message = "Agent Substrate exige Kubernetes 1.37 ou plus."
  }
}

variable "vm_size" {
  type        = string
  default     = "Standard_D4s_v5"
  description = "Taille des nœuds : x86_64, 4 vCPU / 16 Gio."
}

variable "node_count" {
  type        = number
  default     = 2
  description = "Nombre de nœuds (taille fixe)."
}

variable "openai_location" {
  type        = string
  default     = "swedencentral"
  description = "Région de la ressource Azure OpenAI (le catalogue de modèles varie selon la région)."
}

variable "llm_model" {
  type        = string
  default     = "gpt-5.1"
  description = "Modèle Azure OpenAI déployé pour l'agent (vérifier sa disponibilité dans openai_location)."
}

variable "llm_model_version" {
  type        = string
  default     = null
  description = "Version du modèle ; null = version par défaut proposée par Azure."
}

variable "llm_api_version" {
  type        = string
  default     = "2025-04-01-preview"
  description = "Version de l'API Azure OpenAI utilisée par LiteLLM."
}
