variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "mvp-pipeline"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "container_image" {
  description = "Docker container image for the pipeline"
  type        = string
  default     = "mvp-pipeline:latest"
}

variable "github_token_secret_name" {
  description = "AWS Secrets Manager secret name for GitHub token"
  type        = string
  default     = "mvp-pipeline/github-token"
}

variable "vercel_token_secret_name" {
  description = "AWS Secrets Manager secret name for Vercel token"
  type        = string
  default     = "mvp-pipeline/vercel-token"
}

variable "claude_api_key_secret_name" {
  description = "AWS Secrets Manager secret name for Claude API key"
  type        = string
  default     = "mvp-pipeline/claude-api-key"
}

variable "ssh_private_key_secret_name" {
  description = "AWS Secrets Manager secret name for SSH private key"
  type        = string
  default     = "founderdash-ssh-private-key"
}

variable "github_username" {
  description = "GitHub username for repository creation"
  type        = string
  default     = "founderdash-bot"
}

variable "template_repo" {
  description = "Template repository for MVP development"
  type        = string
  default     = "Appemout/event-engagement-toolkit"
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "vercel_token" {
  description = "Vercel API token"
  type        = string
  sensitive   = true
}

variable "vercel_team_id" {
  description = "Vercel team ID"
  type        = string
  sensitive   = true
}

variable "claude_api_key" {
  description = "Claude API key"
  type        = string
  sensitive   = true
}