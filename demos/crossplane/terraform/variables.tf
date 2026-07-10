variable "scaleway_project_id" {
  type        = string
  default     = null
  description = "ID du projet Scaleway (si non défini, utilise la variable d'environnement SCW_DEFAULT_PROJECT_ID)"
}

variable "scaleway_region" {
  type        = string
  default     = "fr-par"
  description = "Région Scaleway pour les ressources"
}

variable "scaleway_zone" {
  type        = string
  default     = "fr-par-2"
  description = "Zone Scaleway pour le pool de nœuds"
}

variable "scaleway_access_key" {
  type        = string
  sensitive   = true
  description = "Scaleway Access Key (utilisée pour créer le secret Crossplane du Provider Scaleway)"
}

variable "scaleway_secret_key" {
  type        = string
  sensitive   = true
  description = "Scaleway Secret Key (utilisée pour créer le secret Crossplane du Provider Scaleway)"
}

variable "crossplane_version" {
  type        = string
  default     = "2.3.3"
  description = "Version du chart Helm Crossplane (2.x requis : composition de ressources Kubernetes arbitraires et extra resources)"
}
