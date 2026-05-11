# AGENTS.md

## Overview

This repo contains a Terraform module for creating Google Cloud Run v2 Jobs with direct VPC egress.

## What This Module Does

Creates Cloud Run Jobs that run inside a VPC, enabling GitHub Actions workflows to execute tasks against VPC resources (PostgreSQL, etc.) without needing bastion hosts or Cloud SQL Proxy.

## Usage in Other Repos

### Import the Module

```hcl
module "vpc_runner" {
  source  = "git::https://github.com/DarojaAI/terraform-gcp-cloudrun-vpc-job.git//modules/cloudrun_vpc_job?ref=v1.0.0"

  name      = "my-task"
  location  = "us-central1"
  project_id = var.project_id

  vpc_network = var.vpc_network
  vpc_subnet  = var.vpc_subnet
  vpc_egress  = "PRIVATE_RANGES_ONLY"

  image    = "gcr.io/project/image:latest"
  command  = ["python", "-m", "my_task"]

  allowed_github_repos = ["DarojaAI/my-repo"]
}
```

### Get VPC Config from Existing Infrastructure

```hcl
data "terraform_remote_state" "network" {
  backend = "gcs"
  config {
    bucket = "my-terraform-state"
    prefix = "prod/network"
  }
}

module "vpc_runner" {
  # ... module config
  vpc_network = data.terraform_remote_state.network.outputs.vpc_id
  vpc_subnet  = data.terraform_remote_state.network.outputs.subnet_id
}
```

## CI/CD Integration

### GitHub Actions Workflow

```yaml
jobs:
  run-vpc-task:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Execute VPC Task
        run: |
          gcloud run jobs execute my-vpc-task \
            --region=us-central1 \
            --project=${{ vars.GCP_PROJECT_ID }} \
            --wait

      - name: Verify Task Completed
        run: |
          echo "Task completed successfully"
```

### Terraform Outputs Available

The module provides these outputs for CI/CD:
- `job_name` - Job name for gcloud commands
- `job_location` - Region
- `gcloud_execute_command` - Ready-to-use gcloud command

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

## Key Concepts

### Direct VPC Egress vs Serverless VPC Access Connector

Cloud Run **Jobs** (not services) support direct VPC egress:
- No extra connector resource required
- Lower latency
- Lower cost
- Jobs get IPs from VPC subnet

Cloud Run **Services** require Serverless VPC Access Connector.

### VPC Egress Modes

- `PRIVATE_RANGES_ONLY`: Only route to RFC1918 private ranges through VPC (recommended for DB access)
- `ALL_TRAFFIC`: Route all egress through VPC

### Workload Identity Federation

The module configures IAM to allow GitHub Actions Workload Identity Federation to execute the job directly, without storing service account keys.
