# =============================================================================
# terraform-gcp-cloudrun-vpc-job
# =============================================================================
# Terraform module registry configuration.
# This file enables the module to be published to Terraform Registry.
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

# Root module passes through to cloudrun_vpc_job
module "vpc_job" {
  source = "./modules/cloudrun_vpc_job"

  # Required
  name       = var.name
  project_id = var.project_id
  vpc_network = var.vpc_network
  vpc_subnet  = var.vpc_subnet
  image      = var.image

  # Optional with defaults
  location = var.location
  vpc_egress = var.vpc_egress
  labels = var.labels

  # Container
  command = var.command
  args    = var.args
  env     = var.env
  secrets = var.secrets

  # Resources
  timeout_seconds = var.timeout_seconds
  parallelism     = var.parallelism
  task_count      = var.task_count
  resources       = var.resources
  cpu_idle        = var.cpu_idle

  # IAM
  github_wif_pool      = var.github_wif_pool
  allowed_github_repos  = var.allowed_github_repos
  grant_subnet_access  = var.grant_subnet_access
}

# =============================================================================
# Variables (passthrough)
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

variable "vpc_network" {
  description = "VPC network self-link"
  type        = string
}

variable "vpc_subnet" {
  description = "VPC subnet self-link"
  type        = string
}

variable "vpc_egress" {
  description = "VPC egress mode: PRIVATE_RANGES_ONLY or ALL_TRAFFIC"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"
}

variable "image" {
  description = "Container image URI"
  type        = string
}

variable "command" {
  description = "Container entrypoint command"
  type        = list(string)
  default     = []
}

variable "args" {
  description = "Container arguments"
  type        = list(string)
  default     = []
}

variable "env" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of env var name to Secret Manager secret ID"
  type        = map(string)
  default     = {}
}

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
  description = "Resource limits"
  type        = map(string)
  default     = {}
}

variable "cpu_idle" {
  description = "Keep CPU allocated between tasks"
  type        = bool
  default     = true
}

variable "github_wif_pool" {
  description = "GitHub WIF pool name"
  type        = string
  default     = "DarojaAI-github-actions-pool"
}

variable "allowed_github_repos" {
  description = "GitHub repos allowed to execute"
  type        = list(string)
  default     = []
}

variable "grant_subnet_access" {
  description = "Grant job service account subnet access"
  type        = bool
  default     = false
}

variable "conditions" {
  description = "Job execution conditions"
  type        = string
  default     = "ALLOW"
}

# =============================================================================
# Outputs (passthrough)
# =============================================================================

output "job_name" {
  description = "Cloud Run Job name"
  value       = module.vpc_job.job_name
}

output "job_id" {
  description = "Cloud Run Job ID"
  value       = module.vpc_job.job_id
}

output "job_location" {
  description = "Cloud Run Job region"
  value       = module.vpc_job.job_location
}

output "job_service_account" {
  description = "Service account for the job"
  value       = module.vpc_job.job_service_account
}

output "gcloud_execute_command" {
  description = "gcloud command to execute this job"
  value       = module.vpc_job.gcloud_execute_command
}
