# outputs.tf
output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.my_app_instance.public_ip
}

output "instance_public_dns" {
  description = "The public DNS name of the EC2 instance"
  value       = aws_instance.my_app_instance.public_dns
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.my_app_alb.dns_name
}


