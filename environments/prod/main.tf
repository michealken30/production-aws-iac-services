provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  environment           = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  enable_nat_gateway    = true
  single_nat_gateway    = false  # One NAT per AZ for high availability
  tags                  = var.tags
}

# Compute Module (EC2-based)
module "compute" {
  source = "../../modules/compute"

  environment              = var.environment
  vpc_id                  = module.networking.vpc_id
  public_subnet_ids       = module.networking.public_subnet_ids
  private_subnet_ids      = module.networking.private_subnet_ids
  
  instance_type           = var.instance_type
  instance_count          = var.instance_count
  container_port          = var.container_port
  health_check_path       = var.health_check_path
  key_name               = var.key_name
  ssh_cidr_blocks        = var.ssh_cidr_blocks
  
  min_size               = var.min_size
  max_size               = var.max_size
  desired_capacity       = var.desired_capacity
  enable_detailed_monitoring = var.enable_detailed_monitoring
  root_volume_size       = var.root_volume_size
  
  tags                   = var.tags
}

# Observability Module
module "observability" {
  source = "../../modules/observability"

  environment        = var.environment
  aws_region        = var.aws_region
  asg_name          = module.compute.asg_name
  log_group_name    = module.compute.log_group_name
  alb_arn_suffix    = module.compute.alb_arn_suffix
  target_group_arn  = module.compute.target_group_arn
  tags              = var.tags
}