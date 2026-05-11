# =============================================================================
# GCP Cloud Run VPC Job Module
# =============================================================================
# Creates a Cloud Run v2 Job with VPC access using existing connector.
# Enables tasks to run inside a VPC from GitHub Actions without Cloud SQL Proxy.
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
# Data: Lookup existing VPC Access Connector
# =============================================================================

data "google_vpc_access_connector" "existing" {
  name    = var.vpc_connector_name
  project = var.project_id
}

locals {
  connector_id = var.vpc_connector_id != "" ? var.vpc_connector_id : data.google_vpc_access_connector.existing.id
}

# =============================================================================
# Enable Required APIs
# =============================================================================

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# =============================================================================
# Service Account for Job Execution
# =============================================================================

resource "google_service_account" "job_sa" {
  project      = var.project_id
  account_id   = "${var.name}-sa"
  display_name = "Service account for ${var.name} Cloud Run VPC Job"
}

# =============================================================================
# Cloud Run v2 Job with VPC Access
# =============================================================================

resource "google_cloud_run_v2_job" "vpc_job" {
  project  = var.project_id
  name     = var.name
  location = var.location
  labels   = var.labels

  template {
    task_count = var.task_count

    annotations = {
      "run.googleapis.com/vpc-access-connector" = local.connector_id
      "run.googleapis.com/vpc-access-egress"    = var.vpc_egress
    }

    # Nested template for container execution
    template {
      timeout          = "${var.timeout_seconds}s"
      service_account  = google_service_account.job_sa.email

      containers {
        image = var.image
        name  = var.name

        command = var.command
        args    = var.args

        # Environment variables
        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }

        # Secrets from Secret Manager
        dynamic "secret" {
          for_each = var.secrets
          content {
            name = secret.key
            value_source {
              secret_manager_secret {
                secret  = secret.value
                version = "latest"
              }
            }
          }
        }

        resources {
          limits = var.resources
        }
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# =============================================================================
# IAM - GitHub Actions Workload Identity Federation
# =============================================================================

resource "google_cloud_run_v2_job_iam_member" "github_actions_execute" {
  for_each = toset(var.allowed_github_repos)

  project  = var.project_id
  location = google_cloud_run_v2_job.vpc_job.location
  name     = google_cloud_run_v2_job.vpc_job.name
  role     = "roles/run.invoker"
  member   = "principalSet:iam.googleapis.com/projects/${var.project_id}/locations/global/workloadIdentityPools/${var.github_wif_pool}/subject/repo:${each.value}"
}

# =============================================================================
# IAM - Allow job to read secrets from Secret Manager
# =============================================================================

resource "google_secret_manager_secret_iam_member" "job_secrets_access" {
  for_each = toset(keys(var.secrets))

  project   = var.project_id
  secret_id = var.secrets[each.value]
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.job_sa.email}"
}