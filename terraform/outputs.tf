# terraform/outputs.tf

output "custom_domain_url" {
  description = "Load Balancer URL for the Flask application"
  value       = aws_lb.my_app_alb.dns_name
}