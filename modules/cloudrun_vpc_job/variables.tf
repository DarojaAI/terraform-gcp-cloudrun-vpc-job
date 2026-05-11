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

variable "vpc_network" {
  description = "VPC network self-link (projects/PROJECT/global/networks/NAME)"
  type        = string
}

variable "vpc_subnet" {
  description = "VPC subnet self-link (projects/PROJECT/regions/REGION/subnetworks/NAME)"
  type        = string
}

variable "vpc_egress" {
  description = "VPC egress mode: PRIVATE_RANGES_ONLY or ALL_TRAFFIC"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition     = contains(["PRIVATE_RANGES_ONLY", "ALL_TRAFFIC"], var.vpc_egress)
    error_message = "vpc_egress must be PRIVATE_RANGES_ONLY or ALL_TRAFFIC"
  }
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

variable "parallelism" {
  description = "Maximum number of parallel tasks"
  type        = number
  default     = 1
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

variable "cpu_idle" {
  description = "Keep CPU allocated between tasks"
  type        = bool
  default     = true
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

# =============================================================================
# Retry Configuration
# =============================================================================

variable "conditions" {
  description = "Job execution conditions"
  type        = string
  default     = "ALLOW"
}
