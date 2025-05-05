# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Define a variable for the Docker image name
variable "image_name" {
  description = "The full name of the Docker image to run (including repository URI and tag)."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "il-central-1" # Match your Jenkinsfile default
}

variable "container_port" {
  description = "The port the application inside the container listens on."
  type        = number
  default     = 80 # Common default for web servers like Nginx
}

variable "app_name" {
  description = "A name for your application and related AWS resources."
  type        = string
  default     = "my-nginx-app" # A default name
}

# Create an ECS Cluster (if you don't have one)
# This is a logical grouping of tasks or services.
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster"
}

# Define an IAM Role for the ECS Task Execution
# This role grants ECS permissions to pull images from ECR, write logs to CloudWatch, etc.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name}-ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Attach the necessary policy to the Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Define the ECS Task Definition
# This describes your container(s), including the image to use, CPU/memory, ports, etc.
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.app_name}-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc" # Required for Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"    # Specify desired CPU units (e.g., 256 (.25 vCPU), 512 (.5 vCPU), 1024 (1 vCPU))
  memory                   = "512"    # Specify desired memory (e.g., 512MB, 1024MB, 2048MB)

  container_definitions = jsonencode([{
    name      = var.app_name
    image     = var.image_name
    cpu       = 256 # CPU units allocated to this container within the task
    memory    = 512 # Memory allocated to this container within the task
    essential = true
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port # With Fargate, hostPort should typically match containerPort
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group" = "/ecs/${var.app_name}"
        "awslogs-region" = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# Create a CloudWatch Log Group for the container logs
resource "aws_cloudwatch_log_group" "app_log_group" {
  name = "/ecs/${var.app_name}"
  retention_in_days = 7 # How long to retain logs
}


# Define an ECS Service
# This maintains a desired count of running tasks and can handle scaling, load balancing, etc.
resource "aws_ecs_service" "app_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1 # Number of tasks to keep running
  launch_type     = "FARGATE"

  network_configuration {
    # You need to specify subnets and security groups for Fargate
    # Replace with your actual VPC subnet and security group IDs
    subnets         = ["subnet-xxxxxxxxxxxxxxxxx"] # IMPORTANT: Replace with your subnet ID(s)
    security_groups = ["sg-xxxxxxxxxxxxxxxxx"] # IMPORTANT: Replace with your security group ID(s)
    assign_public_ip = true # Set to true if you want a public IP for direct access (for testing)
  }

  # Optional: Add a load balancer block if you want to use an ALB/NLB
  # load_balancer {
  #   target_group_arn = aws_lb_target_group.app_target_group.arn
  #   container_name   = var.app_name
  #   container_port   = var.container_port
  # }

  # Ensure the log group is created before the service
  depends_on = [
    aws_cloudwatch_log_group.app_log_group
  ]
}

# Output the ECS Service name and cluster name
output "ecs_service_name" {
  description = "The name of the ECS service."
  value       = aws_ecs_service.app_service.name
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.app_cluster.name
}
