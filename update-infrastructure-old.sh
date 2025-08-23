#!/bin/bash

set -euo pipefail

echo "Updating existing resources..."

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo "Error: .env.local file not found!"
    echo "Please copy .env.local.example to .env.local and update the values."
    exit 1
fi

# Load environment variables from .env.local
echo "Loading configuration from .env.local..."

# Source the .env.local file while filtering out comments and empty lines
set -a  # automatically export all variables
source <(grep -E '^[A-Z_].*=' .env.local | grep -v '^#')
set +a  # stop automatically exporting

# Set Terraform variables using TF_VAR prefix to avoid prompts
export TF_VAR_github_token="$GITHUB_TOKEN"
export TF_VAR_vercel_token="$VERCEL_TOKEN"
export TF_VAR_vercel_team_id="$VERCEL_TEAM_ID"
export TF_VAR_claude_api_key="$CLAUDE_API_KEY"

# Check required variables
required_vars=(
    "GITHUB_TOKEN"
    "VERCEL_TOKEN"
    "VERCEL_TEAM_ID"
    "CLAUDE_API_KEY"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "Error: Required variable $var is not set in .env.local"
        exit 1
    fi
done

echo "Successfully loaded tokens:"
echo "- GITHUB_TOKEN: ${GITHUB_TOKEN:0:10}..."
echo "- VERCEL_TOKEN: ${VERCEL_TOKEN:0:10}..."
echo "- VERCEL_TEAM_ID: ${VERCEL_TEAM_ID}"
echo "- CLAUDE_API_KEY: ${CLAUDE_API_KEY:0:10}..."

cd infrastructure

# Set Terraform variables as environment variables to avoid prompts
export TF_VAR_github_token="$GITHUB_TOKEN"
export TF_VAR_vercel_token="$VERCEL_TOKEN"
export TF_VAR_vercel_team_id="$VERCEL_TEAM_ID"
export TF_VAR_claude_api_key="$CLAUDE_API_KEY"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Import existing resources to avoid conflicts
echo "Importing existing resources..."

# Import existing secrets (ignore errors if they don't exist)
terraform import aws_secretsmanager_secret.github_token "mvp-pipeline/github-token" 2>/dev/null || echo "GitHub secret doesn't exist or already imported"
terraform import aws_secretsmanager_secret.vercel_token "mvp-pipeline/vercel-token" 2>/dev/null || echo "Vercel secret doesn't exist or already imported"  
terraform import aws_secretsmanager_secret.claude_api_key "mvp-pipeline/claude-api-key" 2>/dev/null || echo "Claude secret doesn't exist or already imported"

# Import existing log group
terraform import aws_cloudwatch_log_group.mvp_pipeline_logs "/aws/batch/mvp-pipeline" 2>/dev/null || echo "Log group doesn't exist or already imported"

# Import existing event bus
terraform import aws_cloudwatch_event_bus.mvp_development "mvp-development" 2>/dev/null || echo "Event bus doesn't exist or already imported"

# Plan and apply with updates
echo "Planning Terraform deployment with updates..."
terraform plan -var-file=terraform.tfvars

# Ask for confirmation
read -p "Do you want to apply these changes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Apply the changes
    echo "Applying Terraform changes..."
    terraform apply -var-file=terraform.tfvars -auto-approve
    
    echo "Deployment complete!"
    echo "Your infrastructure has been updated with the secrets from .env.local"
    echo "AWS Batch jobs now have access to the required environment variables."
else
    echo "Deployment cancelled."
fi
