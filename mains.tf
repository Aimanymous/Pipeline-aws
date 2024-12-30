##aiman

# Provider Configuration
provider "aws" {
  region = "ap-southeast-1"  # Singapore region
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Subnet Configuration
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
}

# Route Table for Public Subnet
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main.id
}

# Security Group for Fargate
resource "aws_security_group" "fargate_sg" {
  name        = "fargate-security-group"
  description = "Allow inbound HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECR Repository Configuration
resource "aws_ecr_repository" "app_repo" {
  name = "my-app-repo"
}

# IAM Role for ECS Fargate Task
resource "aws_iam_role" "ecs_role" {
  name = "ecs-fargate-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role for ECS Task Execution (to pull from ECR)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-fargate-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Amazon ECS Task Execution Policy to the execution role
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "my-ecs-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = aws_iam_role.ecs_role.arn
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "my-app-container"
    image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
    essential = true
    memory    = 512
    cpu       = 256
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
      }
    ]
  }])
}

# ECS Service (Fargate)
resource "aws_ecs_service" "app_service" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    security_groups = [aws_security_group.fargate_sg.id]
    subnets          = [aws_subnet.subnet1.id]
    assign_public_ip = true
  }

  depends_on = [aws_security_group.fargate_sg]
}

# S3 Bucket (ensure uniqueness)
resource "aws_s3_bucket" "aiman_bucket" {
  bucket = "my-unique-aiman-bucket-12345"  # Ensure this bucket name is globally unique
}

# CloudWatch Event Rule to Trigger ECS Task
resource "aws_cloudwatch_event_rule" "trigger_rule" {
  name        = "trigger-rule"
  description = "Trigger rule for ECS task"
  schedule_expression = "rate(1 hour)"  # Adjust the schedule as needed
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "ecs_target" {
  rule          = aws_cloudwatch_event_rule.trigger_rule.name
  target_id     = "ecs-task"
  arn           = aws_ecs_cluster.main.arn
  role_arn      = aws_iam_role.ecs_execution_role.arn
  ecs_target {
    task_definition_arn = aws_ecs_task_definition.app_task.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets = [aws_subnet.subnet1.id]
    }
  }
}

# IAM Role for CloudWatch to Trigger ECS Tasks
resource "aws_iam_role" "cloudwatch_iam_role" {
  name = "cloudwatch-iam-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach Policies to CloudWatch IAM Role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.cloudwatch_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

# Outputs
output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.aiman_bucket.id
}
