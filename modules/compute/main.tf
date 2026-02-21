# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name        = "${var.environment}-alb-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2" {
  name        = "${var.environment}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH from trusted IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name        = "${var.environment}-ec2-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}



# IAM Role for EC2 instances
resource "aws_iam_role" "ec2" {
  name = "${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge({
    Name        = "${var.environment}-ec2-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.environment}-instance-profile"
  role = aws_iam_role.ec2.name

  tags = merge({
    Name        = "${var.environment}-instance-profile"
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

# ATTACH AWS MANAGED POLICIES (This is crucial - use these instead of custom policy)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Additional custom policy for your specific needs
resource "aws_iam_role_policy" "ec2_custom" {
  name = "${var.environment}-ec2-custom-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.environment}-app-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {}))

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = var.root_volume_size
      volume_type = var.root_volume_type
      delete_on_termination = true
      encrypted = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      Name        = "${var.environment}-app-instance"
      Environment = var.environment
      ManagedBy   = "terraform"
    }, var.tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge({
      Name        = "${var.environment}-app-volume"
      Environment = var.environment
      ManagedBy   = "terraform"
    }, var.tags)
  }
}


# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name               = "${var.environment}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size           = var.min_size
  max_size           = var.max_size
  desired_capacity   = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app.arn]
  health_check_type = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value              = "${var.environment}-asg"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value              = tag.value
      propagate_at_launch = true
    }
  }
}


# Application Load Balancer
resource "aws_lb" "app" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  tags = merge({
    Name        = "${var.environment}-alb"
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

# Target Group
resource "aws_lb_target_group" "app" {
  name        = "${var.environment}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = "200-399"
  }

  tags = merge({
    Name        = "${var.environment}-tg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

# ALB Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ec2/${var.environment}-http-server"
  retention_in_days = 30

  tags = merge({
    Name        = "${var.environment}-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.environment}-cpu-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_autoscaling_policy" "memory" {
  name                   = "${var.environment}-memory-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "Scale up if CPU > 70% for 10 minutes"
  alarm_actions       = [aws_autoscaling_policy.cpu.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.environment}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "Scale down if CPU < 30% for 25 minutes"
  alarm_actions       = [aws_autoscaling_policy.cpu.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}