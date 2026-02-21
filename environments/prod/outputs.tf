output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.compute.alb_dns_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.compute.asg_name
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = module.compute.log_group_name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.observability.dashboard_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = module.observability.sns_topic_arn
}

output "test_command" {
  description = "Command to test the service"
  value       = "curl http://${module.compute.alb_dns_name}"
}