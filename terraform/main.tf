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
resource "aws_security_group" "my_app_sg" {
  name_prefix = "my-devops-project-sg-"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.my_app_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "my-devops-project-security-group"
  }
}

# Create an EC2 instance
resource "aws_instance" "my_app_instance" {
  ami           = "ami-002db26d4a4c670c1" # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type, us-east-1
  instance_type = "t2.micro" # Free tier eligible
  subnet_id     = aws_subnet.my_app_subnet.id
  vpc_security_group_ids = [aws_security_group.my_app_sg.id]
  associate_public_ip_address = true # Assign a public IP

  # User data to install Docker and run our Flask app
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update -y
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io
              sudo usermod -aG docker ubuntu # Add ubuntu user to docker group
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo docker run -d -p 80:5000 ${var.docker_image_name} # Run our Flask app on port 80 (HTTP)
              EOF

  tags = {
    Name = "my-devops-project-ec2-instance"
  }
}

