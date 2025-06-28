# terraform/monitoring.tf

# --- SNS Topic for Email Notifications ---
# This SNS topic will receive notifications from CloudWatch Alarms.
# You will subscribe your email address to this topic.
resource "aws_sns_topic" "devops_alerts" {
  name = "my-devops-project-alerts"
  tags = {
    Name = "my-devops-project-alerts-topic"
  }
}

# SNS Topic Subscription
# IMPORTANT: After Terraform applies this, you will receive an email
# asking you to confirm the subscription. You MUST click the confirmation link.
resource "aws_sns_topic_subscription" "devops_alerts_email_subscription" {
  topic_arn = aws_sns_topic.devops_alerts.arn
  protocol  = "email"
  endpoint  = "your-email@example.com" # <--- REPLACE WITH YOUR ACTUAL EMAIL ADDRESS
  # Set confirmation_timeout_in_minutes to avoid manual confirmation issues for automated tests
  # For personal use, confirmation_timeout_in_minutes is less critical, but confirm promptly.
}

# --- CloudWatch Metric Alarms ---

# ALB 5XX Errors Alarm
# Triggers if the Application Load Balancer reports any 5XX errors from the target group.
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors_alarm" {
  alarm_name          = "my-flask-app-alb-5xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60 # 1 minute
  statistic           = "Sum"
  threshold           = 1 # If 1 or more 5XX errors in 1 minute
  alarm_description   = "Alarm when ALB reports 5XX errors from Flask app"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.devops_alerts.arn]
  ok_actions          = [aws_sns_topic.devops_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.my_app_alb.arn # Reference your ALB from main.tf
    TargetGroup  = aws_lb_target_group.my_flask_app_tg.arn # Reference your Target Group from main.tf
  }
  tags = {
    Name = "my-flask-app-alb-5xx-alarm"
  }
}

# ECS Service CPU Utilization Alarm
# Triggers if the average CPU utilization of your ECS service goes above 70% for 2 consecutive minutes.
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization_alarm" {
  alarm_name          = "my-flask-app-ecs-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 70 # If CPU >= 70%
  alarm_description   = "Alarm when ECS Flask app CPU utilization is high"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.devops_alerts.arn]
  ok_actions          = [aws_sns_topic.devops_alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.my_app_cluster.name # Reference your ECS Cluster from main.tf
    ServiceName = aws_ecs_service.my_flask_app_service.name # Reference your ECS Service from main.tf
  }
  tags = {
    Name = "my-flask-app-ecs-cpu-alarm"
  }
}

# RDS CPU Utilization Alarm
# Triggers if the average CPU utilization of your RDS instance goes above 70% for 2 consecutive minutes.
resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization_alarm" {
  alarm_name          = "my-flask-app-rds-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 70 # If CPU >= 70%
  alarm_description   = "Alarm when RDS database CPU utilization is high"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.devops_alerts.arn]
  ok_actions          = [aws_sns_topic.devops_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.my_app_db_instance.identifier # Reference your RDS instance from database.tf
  }
  tags = {
    Name = "my-flask-app-rds-cpu-alarm"
  }
}

# --- CloudWatch Dashboard ---
# A custom dashboard to visualize key metrics from your services.
resource "aws_cloudwatch_dashboard" "my_app_dashboard" {
  dashboard_name = "my-flask-app-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.my_app_alb.arn_suffix, "TargetGroup", aws_lb_target_group.my_flask_app_tg.arn_suffix, { "stat" : "Sum", "label" : "ALB 5XX Errors" }],
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.my_app_cluster.name, "ServiceName", aws_ecs_service.my_flask_app_service.name, { "stat" : "Average", "label" : "ECS CPU Util" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.my_app_cluster.name, "ServiceName", aws_ecs_service.my_flask_app_service.name, { "stat" : "Average", "label" : "ECS Memory Util" }],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.my_app_db_instance.identifier, { "stat" : "Average", "label" : "RDS CPU Util" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.my_app_db_instance.identifier, { "stat" : "Average", "label" : "RDS Connections" }]
          ],
          view       = "timeSeries",
          stacked    = false,
          region     = var.aws_region, # Use the aws_region variable from variables.tf
          title      = "Application & Database Metrics",
          start      = "-PT3H" # Last 3 hours
        }
      },
      # You can add more widgets here for other metrics, text, or logs
    ]
  })
  tags = {
    Name = "my-flask-app-overview-dashboard"
  }
}

# Output the SNS topic ARN for easy reference
output "sns_topic_arn" {
  description = "The ARN of the SNS topic for alerts"
  value       = aws_sns_topic.devops_alerts.arn
}

# Output the CloudWatch Dashboard URL
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.my_app_dashboard.dashboard_name}"
}

