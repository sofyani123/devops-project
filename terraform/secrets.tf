# terraform/secrets.tf

# AWS Secrets Manager Secret for RDS credentials
resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "my-flask-app/rds-credentials"
  description             = "RDS database credentials for my Flask application"
  recovery_window_in_days = 0 # Immediately delete the secret on destroy (for dev/test)

  tags = {
    Name    = "my-flask-app-rds-credentials"
    Project = "my-devops-project"
  }
}

# Secret version, holding the actual credentials
resource "aws_secretsmanager_secret_version" "rds_credentials_version" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id

  # Store the credentials as a JSON string
  secret_string = jsonencode({
    username = aws_db_instance.my_app_db_instance.username
    password = aws_db_instance.my_app_db_instance.password
    host     = aws_db_instance.my_app_db_instance.address
    port     = aws_db_instance.my_app_db_instance.port
    dbname   = aws_db_instance.my_app_db_instance.db_name
  })
}

# Output the ARN of the secret, needed for ECS task role permissions.
output "rds_secret_arn" {
  description = "The ARN of the RDS credentials secret"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}
