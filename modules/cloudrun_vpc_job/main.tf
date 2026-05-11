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
# Data: Lookup existing VPC and Subnet
# =============================================================================

data "google_compute_network" "vpc" {
  name    = var.vpc_name
  project = var.project_id
}

data "google_compute_subnetwork" "subnet" {
  name    = var.vpc_subnet_name
  project = var.project_id
  region  = var.location
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

    # Nested template for container execution
    template {
      timeout          = "${var.timeout_seconds}s"
      service_account  = google_service_account.job_sa.email

      # VPC access for direct connectivity to PostgreSQL
      vpc_access {
        network_interfaces {
          network    = data.google_compute_network.vpc.name
          subnetwork = data.google_compute_subnetwork.subnet.name
        }
        egress = "PRIVATE_RANGES_ONLY"
      }

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

        # Secrets from Secret Manager (uses env block with value_source)
        dynamic "env" {
          for_each = var.secrets
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
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

# Also add SA to existing postgres password secret if referenced
data "google_secret_manager_secret" "postgres_password" {
  count = var.secrets["POSTGRES_PASSWORD"] != "" ? 1 : 0
  project = var.project_id
  secret_id = var.secrets["POSTGRES_PASSWORD"]
}

resource "google_secret_manager_secret_iam_member" "job_postgres_password_access" {
  count = var.secrets["POSTGRES_PASSWORD"] != "" ? 1 : 0
  project = var.project_id
  secret_id = data.google_secret_manager_secret.postgres_password[0].secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.job_sa.email}"
}