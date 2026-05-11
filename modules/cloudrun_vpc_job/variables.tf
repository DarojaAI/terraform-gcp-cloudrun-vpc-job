# =============================================================================
# Variables - GCP Cloud Run VPC Job Module
# =============================================================================

variable "name" {
  description = "Name of the Cloud Run Job"
  type        = string
}

variable "location" {
  description = "GCP region for the job"
  type        = string
  default     = "us-central1"
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the job"
  type        = map(string)
  default     = {}
}

# =============================================================================
# VPC Configuration
# =============================================================================

variable "vpc_connector_name" {
  description = "VPC Access Connector name (e.g., dev-nexus-prod-connector)"
  type        = string
  default     = ""
}

variable "vpc_connector_id" {
  description = "Full VPC Access Connector ID (projects/PROJECT/locations/REGION/connectors/NAME). Takes precedence over vpc_connector_name."
  type        = string
  default     = ""
}

variable "vpc_egress" {
  description = "VPC egress mode: private-ranges-only or all-traffic"
  type        = string
  default     = "private-ranges-only"
}

# =============================================================================
# Container Configuration
# =============================================================================

variable "image" {
  description = "Container image URI"
  type        = string
}

variable "command" {
  description = "Container entrypoint command (overrides image CMD)"
  type        = list(string)
  default     = []
}

variable "args" {
  description = "Container arguments"
  type        = list(string)
  default     = []
}

variable "env" {
  description = "Environment variables to pass to the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of env var name to Secret Manager secret ID"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Resource Configuration
# =============================================================================

variable "timeout_seconds" {
  description = "Job execution timeout in seconds"
  type        = number
  default     = 300
}

variable "task_count" {
  description = "Number of tasks to execute"
  type        = number
  default     = 1
}

variable "resources" {
  description = "Resource limits (cpu, memory)"
  type        = map(string)
  default     = {}
}

# =============================================================================
# IAM Configuration
# =============================================================================

variable "github_wif_pool" {
  description = "GitHub Workload Identity Federation pool name"
  type        = string
  default     = "DarojaAI-github-actions-pool"
}

variable "allowed_github_repos" {
  description = "List of GitHub repos allowed to execute the job (format: owner/repo)"
  type        = list(string)
  default     = []
}

variable "grant_subnet_access" {
  description = "Grant the job service account subnet access"
  type        = bool
  default     = false
}

