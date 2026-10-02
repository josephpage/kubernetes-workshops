variable "project_id" {
  type        = string
  description = "Projet Google Cloud de l'atelier (TF_VAR_project_id)."
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "Région du cluster, du dépôt Artifact Registry et du bucket de snapshots."
}

variable "zone" {
  type        = string
  default     = "europe-west1-b"
  description = "Zone du cluster (cluster zonal : un seul plan de contrôle, moins coûteux)."
}

variable "cluster_name" {
  type        = string
  default     = "ax-workshop"
  description = "Nom du cluster GKE ; sert aussi de préfixe aux autres ressources."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.37"
  description = "Version minimale du plan de contrôle. Agent Substrate exige 1.37+ (canal RAPID en octobre 2026)."

  validation {
    condition     = can(regex("^1\\.(3[7-9]|[4-9][0-9])", var.kubernetes_version))
    error_message = "Agent Substrate exige Kubernetes 1.37 ou plus."
  }
}

variable "machine_type" {
  type        = string
  default     = "n2-standard-4"
  description = "Type de machine des nœuds : x86_64, 4 vCPU / 16 Go."
}

variable "node_count" {
  type        = number
  default     = 2
  description = "Nombre de nœuds (taille fixe)."
}

variable "llm_model" {
  type        = string
  default     = "gemini-3.8-flash"
  description = "Modèle Vertex AI utilisé par l'agent, sans le préfixe vertex_ai/."
}

variable "llm_location" {
  type        = string
  default     = "global"
  description = "Emplacement Vertex AI du modèle (global, ou une région)."
}
