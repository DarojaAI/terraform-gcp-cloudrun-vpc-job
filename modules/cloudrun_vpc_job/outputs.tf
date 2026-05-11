# =============================================================================
# Outputs - GCP Cloud Run VPC Job Module
# =============================================================================

output "job_name" {
  description = "Cloud Run Job name"
  value       = google_cloud_run_v2_job.vpc_job.name
}

output "job_id" {
  description = "Cloud Run Job full resource ID"
  value       = google_cloud_run_v2_job.vpc_job.id
}

output "job_location" {
  description = "Cloud Run Job region"
  value       = google_cloud_run_v2_job.vpc_job.location
}

output "job_service_account" {
  description = "Service account email for the job"
  value       = google_service_account.job_sa.email
}

output "gcloud_execute_command" {
  description = "gcloud command to execute this job"
  value       = "gcloud run jobs execute ${google_cloud_run_v2_job.vpc_job.name} --region=${google_cloud_run_v2_job.vpc_job.location} --project=${var.project_id} --wait"
}

output "gha_step" {
  description = "GitHub Actions step for triggering this job"
  value       = <<-EOT
    - name: Execute VPC Task
      run: |
        gcloud run jobs execute ${google_cloud_run_v2_job.vpc_job.name} \
          --region=${google_cloud_run_v2_job.vpc_job.location} \
          --project=${var.project_id} \
          --wait
  EOT
}
