# =============================================================================
# GCP Cloud Run VPC Job Module
# =============================================================================
# Creates a Cloud Run v2 Job with direct VPC egress.
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
# Enable Required APIs
# =============================================================================

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ])

  service            = each.value
  disable_on_destroy = false
}

# =============================================================================
# Service Account for Job Execution
# =============================================================================

resource "google_service_account" "job_sa" {
  project      = var.project_id
  account_id   = "${var.name}-vpc-job-sa"
  display_name = "Service account for ${var.name} Cloud Run VPC Job"
}

# =============================================================================
# Cloud Run v2 Job with Direct VPC Egress
# =============================================================================

resource "google_cloud_run_v2_job" "vpc_job" {
  project  = var.project_id
  name     = var.name
  location = var.location
  labels   = var.labels

  # Retry configuration
  conditions = var.conditions

  template {
    parallelism = var.parallelism
    task_count  = var.task_count
    timeout     = "${var.timeout_seconds}s"

    template {
      # Direct VPC Egress - no connector required for jobs
      vpc_access {
        egress      = var.vpc_egress
        network     = var.vpc_network
        subnetwork  = var.vpc_subnet
        # Note: Egress uses subnetwork's secondary range for service networking
      }

      containers {
        image = var.image
        name  = var.name

        # Environment variables
        dynamic "env" {
          for_each = var.env
          content {
            name  = env.key
            value = env.value
          }
        }

        # Secrets from Secret Manager
        dynamic "env" {
          for_each = var.secrets
          content {
            name = secret.key
            value_source {
              secret_manager_secret {
                secret = secret.value
                version = "latest"
              }
            }
          }
        }

        # Startup command override
        dynamic "command" {
          for_each = length(var.command) > 0 ? [var.command] : []
          content {
            command = command.value
          }
        }

        # Startup args override
        dynamic "args" {
          for_each = length(var.args) > 0 ? [var.args] : []
          content {
            args = args.value
          }
        }

        # Resource limits
        resources {
          limits = var.resources
          cpu_idle = var.cpu_idle
        }
      }

      # Service account for execution
      service_account = google_service_account.job_sa.email
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
  member   = "principalSet:iam.googleapis.com/projects/${google_project_service.apis["cloudresourcemanager.googleapis.com"].project}/locations/global/workloadIdentityPools/${var.github_wif_pool}/subject/repo:${each.value}"
}

# =============================================================================
# IAM - Allow job to read secrets from Secret Manager
# =============================================================================

resource "google_secret_manager_secret_iam_member" "job_secrets_access" {
  for_each = toset(keys(var.secrets))

  project = var.project_id
  secret_id = var.secrets[each.value]
  role    = "roles/secretmanager.secretAccessor"
  member   = "serviceAccount:${google_service_account.job_sa.email}"
}

# =============================================================================
# Optional: VPC subnet IAM for job service account
# =============================================================================

resource "google_compute_subnetwork_iam_member" "job_vpc_access" {
  count      = var.grant_subnet_access ? 1 : 0
  subnetwork = var.vpc_subnet
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.job_sa.email}"
}
