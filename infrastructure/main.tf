terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC and networking (using default VPC for simplicity)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for Fargate tasks
resource "aws_security_group" "mvp_pipeline_sg" {
  name_prefix = "mvp-pipeline-"
  vpc_id      = data.aws_vpc.default.id

  # Outbound HTTPS for API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP for package downloads
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound SSH for Git operations
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mvp-pipeline-sg"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "mvp_pipeline_logs" {
  name              = "/aws/batch/mvp-pipeline"
  retention_in_days = 30

  tags = {
    Name = "mvp-pipeline-logs"
  }
}

# EventBridge Custom Bus
resource "aws_cloudwatch_event_bus" "mvp_development" {
  name = "mvp-development"

  tags = {
    Name = "mvp-development-bus"
  }
}