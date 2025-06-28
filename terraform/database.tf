# terraform/database.tf

# Data source to retrieve VPC details
data "aws_vpc" "my_app_vpc" {
  id = aws_vpc.my_app_vpc.id
}

# RDS Subnet Group
resource "aws_db_subnet_group" "my_app_db_subnet_group" {
  name = "my-devops-project-db-subnet-group"
  subnet_ids = [
    aws_subnet.my_app_subnet_a.id,
    aws_subnet.my_app_subnet_b.id
  ]
  description = "Subnet group for my Flask app RDS instance"

  tags = {
    Name = "my-devops-project-db-subnet-group"
  }
}

# RDS Security Group
resource "aws_security_group" "my_app_db_sg" {
  name_prefix = "my-devops-project-db-sg-"
  description = "Allow inbound PostgreSQL traffic from ECS tasks"
  vpc_id      = aws_vpc.my_app_vpc.id

  ingress {
    description     = "Allow PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.my_ecs_tasks_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-devops-project-db-security-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "my_app_db_instance" {
  allocated_storage         = 20
  db_name                   = "my_flask_app_db"
  engine                    = "postgres"
  engine_version            = "14.18"
  instance_class            = "db.t3.micro"
  identifier                = "my-flask-app-db-instance"
  username                  = "flaskadmin"
  password                  = "MyRdsPa55word_123!"
  db_subnet_group_name      = aws_db_subnet_group.my_app_db_subnet_group.name
  vpc_security_group_ids    = [aws_security_group.my_app_db_sg.id]
  skip_final_snapshot       = true
  final_snapshot_identifier = "my-flask-app-db-final-snapshot"
  multi_az                  = false
  publicly_accessible       = false

  tags = {
    Name = "my-flask-app-rds-instance"
  }
}

output "rds_endpoint" {
  description = "The endpoint address of the RDS instance"
  value       = aws_db_instance.my_app_db_instance.address
}
