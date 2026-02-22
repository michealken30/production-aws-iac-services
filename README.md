# Production EC2-based Service Infrastructure on AWS
PS: I would have used Ecs fargate which is simplier to set up but to maintain cost effective especially for startup with few users and to own my infrastracture and also make sure the appliction is always available among other things i decided to go with Ec2 setup.

This Terraform configuration deploys a highly available, stateless HTTP service on AWS using EC2 instances behind an Application Load Balancer.

## Architecture Overview

The infrastructure consists of:

Ps: I would have used public modules but i decide to use custom so i expressly show how does things are designed.

- **Networking Layer**: VPC with public/private subnets across 2 AZs
- **Compute Layer**: Auto Scaling Group of EC2 instances with a simple HTTP server
- **Load Balancing**: Application Load Balancer for traffic distribution
- **Observability**: CloudWatch dashboards, logs, and comprehensive alerts
- **State Management**: S3 backend with s3 native lockin

## Key Features

### High Availability
- Multi-AZ deployment (2 availability zones)
- Auto Scaling Group with minimum 3 instances
- Load balancing with health checks
- NAT Gateway per AZ for high availability

### Security
- Instances in private subnets
- Security groups with least-privilege rules
- Encrypted EBS volumes
- IAM roles with minimal permissions
- No public IPs on instances

### Observability
- CloudWatch detailed monitoring
- Structured logging to CloudWatch
- Custom dashboard with:
  - ALB metrics (response time, request count, errors)
  - EC2 metrics (CPU, network, disk)
  - Auto Scaling metrics
  - Error log viewer
- Alarms for:
  - High CPU (>80%)
  - 5XX errors
  - Unhealthy hosts
  - Error log patterns


## Why EC2?

This solution uses EC2 instead of Fargate because:
- **Full control** over the operating system
- **Cost optimization** for predictable workloads
- **Custom AMIs** for faster scaling
- **Host-level access** for debugging
- **SSH access** for troubleshooting


### Production Safety
- S3 backend with state versioning and locking
- Deployment protection on ALB
- Health check grace period
- Auto-scaling policies
- Encrypted root volumes

## Deployment Instructions

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. S3 bucket for state management



## Deployment Instructions

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed


### Step 1: Setup Remote State Infrastructure

```bash
cd global/s3-backend
terraform init
terraform plan
terraform apply -auto-approve


### Step 2: Setup the prod Infrastructure


cd environments/prod
terraform init
terraform plan
terraform apply -auto-approve


```

## AI Usage Disclosure

AI was used to accelerate the initial scaffolding of this Terraform project. Specifically Generating boilerplate resource blocks and module interfaces


All code has been reviewed, understood, and is owned by me. The architectural decisions, module boundaries, and security choices were made by me, and am prepared to explain and defend every line.

## image of my application repo have built before and i used to test




