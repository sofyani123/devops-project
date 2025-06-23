# main.tf
# Define the AWS provider and specify the region
provider "aws" {
  region = "us-east-1" # US East 1 region
}

# Create a new Virtual Private Cloud (VPC)
resource "aws_vpc" "my_app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "my-devops-project-vpc"
  }
}

# Create a public subnet within the VPC
resource "aws_subnet" "my_app_subnet" {
  vpc_id            = aws_vpc.my_app_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Specify an availability zone
  map_public_ip_on_launch = true # Automatically assign public IPs
  tags = {
    Name = "my-devops-project-subnet"
  }
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "my_app_igw" {
  vpc_id = aws_vpc.my_app_vpc.id
  tags = {
    Name = "my-devops-project-igw"
  }
}

# Create a Route Table and associate it with the subnet
resource "aws_route_table" "my_app_route_table" {
  vpc_id = aws_vpc.my_app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_app_igw.id
  }
  tags = {
    Name = "my-devops-project-route-table"
  }
}

resource "aws_route_table_association" "my_app_rta" {
  subnet_id      = aws_subnet.my_app_subnet.id
  route_table_id = aws_route_table.my_app_route_table.id
}

# Create a Security Group to allow inbound SSH and HTTP traffic

resource "aws_security_group" "my_alb_sg" {
  name_prefix = "my-devops-project-alb-sg-"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = aws_vpc.my_app_vpc.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-devops-project-alb-security-group"
  }
}

# Security Group for the ECS Fargate tasks
# This SG allows inbound traffic from the ALB on the application port (5000).
# It also allows all outbound traffic for the tasks to reach the internet.
resource "aws_security_group" "my_ecs_tasks_sg" {
  name_prefix = "my-devops-project-ecs-task-sg-"
  description = "Allow inbound traffic from ALB to ECS tasks on app port"
  vpc_id      = aws_vpc.my_app_vpc.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    # Allow traffic only from the ALB's security group
    security_groups = [aws_security_group.my_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic for tasks
  }

  tags = {
    Name = "my-devops-project-ecs-task-security-group"
  }
}

# --- NEW: IAM Roles for ECS Task Execution and Task Role ---

# IAM role for ECS tasks to allow them to pull images from ECR and send logs to CloudWatch.
# This is the "Task Execution Role".
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "my-devops-project-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "my-devops-project-ecs-task-execution-role"
  }
}

# Attach the managed policy for ECS Task Execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM role for the ECS tasks themselves (if your application needed AWS permissions).
# For this simple Flask app, it doesn't strictly need additional permissions, but it's good practice
# to define a separate Task Role for potential future use.
resource "aws_iam_role" "ecs_task_role" {
  name = "my-devops-project-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "my-devops-project-ecs-task-role"
  }
}

# --- NEW: ECS Cluster, Task Definition, and Service ---

# ECS Cluster
# A logical grouping of tasks or services.
resource "aws_ecs_cluster" "my_app_cluster" {
  name = "my-devops-project-cluster"
  tags = {
    Name = "my-devops-project-ecs-cluster"
  }
}

# CloudWatch Log Group for ECS Task Logs
# All logs from our Flask application running in ECS will be sent here.
resource "aws_cloudwatch_log_group" "my_flask_app_log_group" {
  name              = "/ecs/my-flask-app"
  retention_in_days = 7 # Retain logs for 7 days
  tags = {
    Name = "my-flask-app-log-group"
  }
}

# ECS Task Definition for our Flask application
# This defines our application container, its resources, and networking.
resource "aws_ecs_task_definition" "my_flask_app_task" {
  family                   = "my-flask-app-task"
  # Fargate launch type compatibility
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 0.5 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn # Optional, but good practice

  container_definitions = jsonencode([
    {
      name        = "my-flask-app"
      image       = "${aws_ecr_repository.my_flask_app_ecr.repository_url}:latest" # Referencing ECR repo from ecr.tf
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 5000 # Flask app's port
          hostPort      = 5000 # Not used by Fargate, but required
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.my_flask_app_log_group.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "my-flask-app-task-definition"
  }
}

# Application Load Balancer (ALB)
# Distributes traffic to our ECS tasks.
resource "aws_lb" "my_app_alb" {
  name               = "my-devops-project-alb"
  internal           = false # Public-facing ALB
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_alb_sg.id]
  subnets            = [aws_subnet.my_app_subnet.id] # ALB needs public subnets for external access

  tags = {
    Name = "my-devops-project-alb"
  }
}

# ALB Target Group
# Registers our ECS tasks to receive traffic from the ALB.
resource "aws_lb_target_group" "my_flask_app_tg" {
  name        = "my-flask-app-tg"
  port        = 5000 # Target port on the container
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_app_vpc.id
  target_type = "ip" # Required for Fargate

  health_check {
    path                = "/" # Or a specific health check endpoint like /health
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "my-flask-app-target-group"
  }
}

# ALB Listener (HTTP on port 80)
# Listens for incoming requests and forwards them to the target group.
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.my_flask_app_tg.arn
    type             = "forward"
  }

  tags = {
    Name = "my-devops-project-http-listener"
  }
}

# ECS Service
# Manages the desired count of tasks, deployments, and integrates with the ALB.
resource "aws_ecs_service" "my_flask_app_service" {
  name            = "my-flask-app-service"
  cluster         = aws_ecs_cluster.my_app_cluster.id
  task_definition = aws_ecs_task_definition.my_flask_app_task.arn
  desired_count   = 1 # Number of running tasks
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.my_app_subnet.id]
    security_groups = [aws_security_group.my_ecs_tasks_sg.id]
    assign_public_ip = true # Fargate tasks need public IP in public subnets to pull images
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.my_flask_app_tg.arn
    container_name   = "my-flask-app"
    container_port   = 5000
  }

  # Ensure the service waits for the ALB to be ready
  depends_on = [
    aws_lb_listener.http_listener,
  ]

  tags = {
    Name = "my-flask-app-ecs-service"
  }
}




