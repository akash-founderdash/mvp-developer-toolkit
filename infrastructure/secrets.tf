# Secrets Manager secrets for API tokens
resource "aws_secretsmanager_secret" "github_token" {
  name        = var.github_token_secret_name
  description = "GitHub API token for MVP pipeline"

  tags = {
    Name = "github-token"
  }
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token
}

resource "aws_secretsmanager_secret" "vercel_token" {
  name        = var.vercel_token_secret_name
  description = "Vercel API token for MVP pipeline"

  tags = {
    Name = "vercel-token"
  }
}

resource "aws_secretsmanager_secret_version" "vercel_token" {
  secret_id     = aws_secretsmanager_secret.vercel_token.id
  secret_string = var.vercel_token
}

resource "aws_secretsmanager_secret" "claude_api_key" {
  name        = var.claude_api_key_secret_name
  description = "Claude API key for MVP pipeline"

  tags = {
    Name = "claude-api-key"
  }
}

resource "aws_secretsmanager_secret_version" "claude_api_key" {
  secret_id     = aws_secretsmanager_secret.claude_api_key.id
  secret_string = var.claude_api_key
}