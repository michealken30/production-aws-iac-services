# Production EC2-based Service Infrastructure on AWS

This Terraform configuration deploys a highly available, stateless HTTP service on AWS using EC2 instances behind an Application Load Balancer.

## Architecture Overview

The infrastructure consists of:

- **Networking Layer**: VPC with public/private subnets across 2 AZs
- **Compute Layer**: Auto Scaling Group of EC2 instances with a simple HTTP server
- **Load Balancing**: Application Load Balancer for traffic distribution
- **Observability**: CloudWatch dashboards, logs, and comprehensive alerts
- **State Management**: S3 backend with DynamoDB locking

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
# Production EC2-based Service Infrastructure on AWS

This Terraform configuration deploys a highly available, stateless HTTP service on AWS using EC2 instances behind an Application Load Balancer.

## Architecture Overview

The infrastructure consists of:

- **Networking Layer**: VPC with public/private subnets across 2 AZs
- **Compute Layer**: Auto Scaling Group of EC2 instances with a simple HTTP server
- **Load Balancing**: Application Load Balancer for traffic distribution
- **Observability**: CloudWatch dashboards, logs, and comprehensive alerts
- **State Management**: S3 backend with DynamoDB locking

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

### Production Safety
- S3 backend with state versioning
- DynamoDB state locking
- Deployment protection on ALB
- Health check grace period
- Auto-scaling policies
- Encrypted root volumes

## Why EC2?

This solution uses EC2 instead of Fargate because:
- **Full control** over the operating system
- **Cost optimization** for predictable workloads
- **Custom AMIs** for faster scaling
- **Host-level access** for debugging
- **SSH access** for troubleshooting

## Deployment Instructions

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. S3 bucket and DynamoDB table for state management

### Step 1: Setup Remote State Infrastructure

```bash
cd global/s3-backend
terraform init
terraform plan
terraform apply -auto-approve
### Production Safety
- S3 backend with state versioning
- DynamoDB state locking
- Deployment protection on ALB
- Health check grace period
- Auto-scaling policies
- Encrypted root volumes

## Why EC2?

This solution uses EC2 instead of Fargate because:
- **Full control** over the operating system
- **Cost optimization** for predictable workloads
- **Custom AMIs** for faster scaling
- **Host-level access** for debugging
- **SSH access** for troubleshooting

## Deployment Instructions

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. S3 bucket and DynamoDB table for state management

### Step 1: Setup Remote State Infrastructure

```bash
cd global/s3-backend
terraform init
terraform plan
terraform apply -auto-approve