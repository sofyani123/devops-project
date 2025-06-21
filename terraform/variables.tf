# variables.tf
variable "docker_image_name" {
  description = "The full name and tag of the Docker image to deploy (e.g., your_dockerhub_username/my-flask-app:latest)"
  type        = string
}