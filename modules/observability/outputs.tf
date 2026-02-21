output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = local.sns_topic_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}