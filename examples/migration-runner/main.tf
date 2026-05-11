# =============================================================================
# Example: Database Migration Runner
# =============================================================================
# Creates a Cloud Run Job for running database migrations inside a VPC.
# GitHub Actions can trigger this job to execute migrations without direct DB access.
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "DarojaAI/cloudrun-vpc-job"
      version = "1.0.0"
    }
  }
}

# =============================================================================
# Database Migration Runner
# =============================================================================

module "migration_runner" {
  source  = "../../modules/cloudrun_vpc_job"

  name      = "db-migration-runner"
  location  = "us-central1"
  project_id = var.project_id

  # VPC Configuration (from existing infrastructure)
  vpc_network  = var.vpc_network
  vpc_subnet   = var.vpc_subnet
  vpc_egress   = "PRIVATE_RANGES_ONLY"

  # Container - uses the same app image with migration command
  image   = var.app_image
  command = ["python", "-m", "atlas_migrate", "apply"]

  # Environment variables for database connection
  env = {
    DATABASE_URL = "" # Set via secrets
  }

  # Secrets from Secret Manager
  secrets = {
    DATABASE_URL = "${var.project_id}/db-connection-string"
  }

  # Resource configuration
  timeout_seconds = 600  # 10 minutes for migrations
  resources = {
    cpu   = "1"
    memory = "512Mi"
  }

  # Labels
  labels = {
    purpose = "database-migration"
    managed-by = "terraform"
  }

  # IAM - allow GitHub Actions to execute
  allowed_github_repos = var.allowed_github_repos
}

# =============================================================================
# Variables
# =============================================================================

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "vpc_network" {
  description = "VPC network self-link"
  type        = string
}

variable "vpc_subnet" {
  description = "VPC subnet self-link"
  type        = string
}

variable "app_image" {
  description = "Application container image with migration tools"
  type        = string
}

variable "allowed_github_repos" {
  description = "GitHub repos allowed to execute migrations"
  type        = list(string)
  default     = []
}
