# terraform/outputs.tf

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.my_app_alb.dns_name
}