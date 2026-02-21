# SNS Topic for Alarms (if not provided)
resource "aws_sns_topic" "alarms" {
  count = var.sns_topic_arn == "" ? 1 : 0
  name  = "${var.environment}-alarms"

  tags = merge({
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

locals {
  sns_topic_arn = var.sns_topic_arn != "" ? var.sns_topic_arn : aws_sns_topic.alarms[0].arn
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-service-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }],
            ["AWS/EC2", "NetworkIn", { stat = "Sum" }],
            ["AWS/EC2", "NetworkOut", { stat = "Sum" }],
            ["AWS/EC2", "DiskReadBytes", { stat = "Sum" }],
            ["AWS/EC2", "DiskWriteBytes", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 Instance Metrics"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type = "log"
        properties = {
          query = "SOURCE '${var.log_group_name}' | fields @timestamp, @message\n| filter @message like /ERROR/\n| limit 20"
          region = var.aws_region
          title  = "Recent Error Logs"
          view   = "table"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupTotalInstances", { stat = "Average" }],
            ["AWS/AutoScaling", "GroupInServiceInstances", { stat = "Average" }],
            ["AWS/AutoScaling", "GroupPendingInstances", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Auto Scaling Group Metrics"
          view   = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

# ALB 5XX Error Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.environment}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# ALB 4XX Error Alarm
resource "aws_cloudwatch_metric_alarm" "alb_4xx" {
  alarm_name          = "${var.environment}-alb-4xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors ALB 4XX errors"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# Unhealthy Host Alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.environment}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy hosts in target group"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]

  dimensions = {
    TargetGroup  = var.target_group_arn
    LoadBalancer = var.alb_arn_suffix
  }
}

# Metric Filter for Error Logs
resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "${var.environment}-error-count"
  pattern        = "ERROR"
  log_group_name = var.log_group_name

  metric_transformation {
    name      = "ErrorCount"
    namespace = "ServiceMetrics"
    value     = "1"
  }
}

# Error Count Alarm
resource "aws_cloudwatch_metric_alarm" "error_count" {
  alarm_name          = "${var.environment}-error-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorCount"
  namespace           = "ServiceMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors error count in logs"
  alarm_actions       = [local.sns_topic_arn]
  ok_actions          = [local.sns_topic_arn]
}