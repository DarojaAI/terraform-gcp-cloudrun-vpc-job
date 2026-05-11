# =============================================================================
# Example: Basic Cloud Run VPC Job
# =============================================================================
# Minimal example showing how to run a task inside a VPC from GitHub Actions.
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

# =============================================================================
# Basic VPC Job
# =============================================================================

module "vpc_task" {
  source  = "../../modules/cloudrun_vpc_job"

  name       = "my-vpc-task"
  location   = "us-central1"
  project_id = var.project_id

  # VPC Configuration
  vpc_network = var.vpc_network
  vpc_subnet  = var.vpc_subnet
  vpc_egress  = "PRIVATE_RANGES_ONLY"

  # Container
  image   = "us-docker.pkg.dev/cloudrun/container/hello"
  command = []  # Use image default

  # IAM
  allowed_github_repos = ["DarojaAI/dev-nexus"]

  labels = {
    environment = "production"
  }
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
