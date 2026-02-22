aws_region               = "us-east-1"
environment              = "prod"
vpc_cidr                = "10.0.0.0/16"
availability_zones       = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs     = ["10.0.10.0/24", "10.0.11.0/24"]

instance_type           = "t3.micro"
instance_count          = 3
container_port          = 80
health_check_path       = "/health"
ssh_cidr_blocks         = ["0.0.0.0/0"]  # work ip safer

min_size               = 2
max_size               = 4
desired_capacity       = 2

enable_detailed_monitoring = true
root_volume_size       = 20

tags = {
  Project     = "ProductionService"
  CostCenter  = "Platform"
  Owner       = "DevOps"
  Environment = "prod"
}