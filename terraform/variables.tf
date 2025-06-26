# terraform/variables.tf
variable "aws_region" {
 description = "The AWS region where resources are deployed."
 type = string
 default = "us-east-1" # Set your default region here
}