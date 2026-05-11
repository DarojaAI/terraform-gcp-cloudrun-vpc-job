# Terraform GCP Cloud Run VPC Job Module

A Terraform module for creating Cloud Run v2 Jobs with direct VPC egress. Enables GitHub Actions workflows to execute tasks inside a VPC without needing Cloud SQL Proxy or bastion hosts.

## Features

- **Direct VPC Egress**: Cloud Run Jobs connect directly to VPC subnets (no Serverless VPC Access Connector required for jobs)
- **Private IP Access**: Jobs can reach VPC resources (Cloud SQL, Compute instances, etc.) via internal IPs
- **GitHub Actions Ready**: IAM configured for GHA Workload Identity Federation execution
- **Minimal Configuration**: Only requires VPC/subnet IDs and job command

## Usage

```hcl
module "vpc_job" {
  source  = "DarojaAI/cloudrun-vpc-job/gcp"
  version = "1.0.0"

  name     = "my-task"
  location = "us-central1"
  project_id = "my-project"

  # VPC Configuration
  vpc_network   = "projects/my-project/global/networks/my-vpc"
  vpc_subnet     = "projects/my-project/regions/us-central1/subnetworks/my-subnet"
  vpc_egress     = "PRIVATE_RANGES_ONLY"  # or "ALL_TRAFFIC"

  # Container
  image = "gcr.io/my-project/my-image:latest"
  command = ["python", "-m", "my_module"]

  # IAM - GitHub Actions execution
  allowed_github_repos = ["DarojaAI/*"]
}
```

## Architecture

```
GitHub Actions (outside VPC)
        │
        ▼
Cloud Run Job (inside VPC via direct egress)
        │
        ▼
VPC Resources (PostgreSQL, etc.)
```

## Alternatives

| Approach | Pros | Cons |
|----------|------|------|
| **This module (direct VPC egress)** | Simple, no extra infrastructure | Jobs only, not services |
| Serverless VPC Access Connector | Works for services | Extra connector resource, higher latency |
| Cloud SQL Proxy sidecar | Works everywhere | Sidecar complexity, auth management |
| External IP + firewall | Simple | Security exposure, routing complexity |

## Requirements

- Terraform 1.0+
- Google Cloud Provider 4.0+
- APIs enabled: `run.googleapis.com`, `compute.googleapis.com`

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `name` | Job name | `string` | Yes |
| `location` | GCP region | `string` | Yes |
| `project_id` | GCP project ID | `string` | Yes |
| `vpc_network` | VPC network self-link | `string` | Yes |
| `vpc_subnet` | VPC subnet self-link | `string` | Yes |
| `vpc_egress` | VPC egress mode | `string` | Yes |
| `image` | Container image URI | `string` | Yes |
| `command` | Container entrypoint | `list(string)` | No |
| `allowed_github_repos` | GitHub repos allowed to execute | `list(string)` | No |

## Outputs

| Name | Description |
|------|-------------|
| `job_name` | Cloud Run Job name |
| `job_id` | Cloud Run Job ID |
| `job_location` | Job region |
| `execution_template` | gcloud command template |

## License

MIT
