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

## License

MIT