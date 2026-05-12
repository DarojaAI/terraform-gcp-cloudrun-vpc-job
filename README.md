# terraform-gcp-cloudrun-vpc-job

A Terraform module for creating Google Cloud Run v2 Jobs with direct VPC egress. Enables GitHub Actions workflows to execute tasks inside a VPC without needing Cloud SQL Proxy or bastion hosts.

## Problem This Solves

GitHub Actions runners cannot reach resources inside VPCs (internal IPs, Cloud SQL, etc.). Common workarounds:

- **Cloud SQL Proxy sidecar** - Complex, requires authentication management
- **External IPs + firewall rules** - Security exposure, maintenance burden
- **Bastion hosts** - Extra infrastructure, SSH key management

This module provides a simpler approach: Cloud Run Jobs with direct VPC egress.

## Quick Start

```hcl
module "vpc_job" {
  source  = "DarojaAI/cloudrun-vpc-job/gcp"
  version = "1.0.0"

  name      = "my-task"
  location  = "us-central1"
  project_id = "my-project"

  vpc_network = "projects/my-project/global/networks/my-vpc"
  vpc_subnet  = "projects/my-project/regions/us-central1/subnetworks/my-subnet"
  vpc_egress  = "PRIVATE_RANGES_ONLY"

  image   = "gcr.io/my-project/my-image:latest"
  command = ["python", "-m", "my_task"]

  allowed_github_repos = ["DarojaAI/my-repo"]
}
```

## Architecture

```
GitHub Actions (public internet)
        │
        │ gcloud run jobs execute
        ▼
Cloud Run Job (inside VPC via direct egress)
        │
        │ Internal VPC routing
        ▼
VPC Resources (PostgreSQL, Redis, etc.)
```

## Key Features

- **Direct VPC Egress**: No Serverless VPC Access Connector required for jobs
- **GitHub Actions Native**: IAM configured for Workload Identity Federation
- **Minimal Config**: Just VPC IDs + container image
- **Secrets Integration**: Reads from Secret Manager automatically

## Why Cloud Run Jobs vs Functions/Lambda?

Cloud Run Jobs are designed for **one-off tasks** (migrations, batch jobs, ETL), not HTTP-triggered functions. They:
- Have no HTTP endpoint
- Can run for up to 24 hours
- Support arbitrary entrypoints
- Cost less (billed only when running)

## Multi-Task Jobs with Task Arguments

Cloud Run Jobs support **task arguments** — you can pass arguments at execution time via `--tasks-arg`. This enables a single job to run different tasks:

```hcl
module "vpc_runner" {
  source  = "DarojaAI/cloudrun-vpc-job/gcp"
  version = "1.0.0"

  name      = "my-vpc-runner"
  location  = "us-central1"
  project_id = "my-project"
  # ... VPC config ...

  # Dispatcher script handles routing
  command = ["/app/dispatcher.sh"]
}
```

### Dispatcher Pattern

Create a dispatcher script in your container image that routes based on arguments:

```bash
#!/bin/bash
# /app/dispatcher.sh

TASK="${1:-}"

case "$TASK" in
    migrate)
        exec /app/scripts/run_migrations.sh
        ;;
    dbt)
        exec /app/scripts/run_dbt.sh
        ;;
    *)
        echo "Unknown task: $TASK"
        exit 1
        ;;
esac
```

### Executing Tasks

```bash
# Run migrations
gcloud run jobs execute my-vpc-runner \
  --region=us-central1 \
  --project=my-project \
  --tasks-arg "migrate" \
  --wait

# Run dbt
gcloud run jobs execute my-vpc-runner \
  --region=us-central1 \
  --project=my-project \
  --tasks-arg "dbt" \
  --wait
```

### Benefits

- **Single infrastructure piece** to manage for all VPC-access tasks
- **Shared resources** (image, service account, secrets) across tasks
- **Independent task scripts** — each task has its own logic
- **Easy to extend** — add new cases to the dispatcher without Terraform changes

### Task Timeout Considerations

Each task may have different resource requirements. Use Terraform outputs to track configured timeout:

```hcl
output "vpc_runner_gcloud_command" {
  value = "gcloud run jobs execute ${module.vpc_runner.job_name} --tasks-arg \"migrate\" --wait"
}
```

## License

MIT
