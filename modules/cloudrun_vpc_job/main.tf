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
# Data: Lookup existing VPC, Subnet, and Project Number
# =============================================================================

data "google_project" "project" {
  project_id = var.project_id
}

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
  project            = var.project_id
  name               = var.name
  location           = var.location
  labels             = var.labels
  deletion_protection = false

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


  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.job_secrets_access,
    google_secret_manager_secret_iam_member.job_postgres_password_access,
  ]
}

# =============================================================================
# IAM - GitHub Actions Workload Identity Federation
# =============================================================================

# Grant the WIF service account run.invoker on the job
# The WIF SA is passed as var.wif_service_account_email
resource "google_cloud_run_v2_job_iam_member" "github_actions_execute" {
  project  = var.project_id
  location = google_cloud_run_v2_job.vpc_job.location
  name     = google_cloud_run_v2_job.vpc_job.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.wif_service_account_email}"
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
# NOTE: We reference the secret by name directly instead of using a data source.
# data source evaluation during plan (including destroy) fails if the secret
# doesn't exist yet, causing terraform destroy to abort.
resource "google_secret_manager_secret_iam_member" "job_postgres_password_access" {
  count = var.secrets["POSTGRES_PASSWORD"] != "" ? 1 : 0
  project = var.project_id
  secret_id = var.secrets["POSTGRES_PASSWORD"]
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.job_sa.email}"
}
