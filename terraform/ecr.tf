# terraform/ecr.tf

# This resource creates an AWS Elastic Container Registry (ECR) repository.
# ECR is a fully-managed Docker container registry that makes it easy to store, manage, and deploy Docker container images.
# It integrates seamlessly with AWS ECS.
resource "aws_ecr_repository" "my_flask_app_ecr" {
  name                 = "my-flask-app" # Name of your ECR repository
  image_tag_mutability = "MUTABLE"      # Allows overwriting 'latest' tag
  
  # Configure image scanning on push to automatically scan for vulnerabilities.
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "my-flask-app-ecr-repo"
    Project     = "my-devops-project"
  }
}

# Output the ECR repository URL, which will be needed for Docker push and ECS task definition.
output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.my_flask_app_ecr.repository_url
}
