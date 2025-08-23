#!/bin/bash

set -euo pipefail

echo "Deploying FounderDash MVP EventBridge System..."

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

echo "Successfully loaded tokens from .env.local"

cd infrastructure

# Set Terraform variables as environment variables to avoid prompts
export TF_VAR_github_token="$GITHUB_TOKEN"
export TF_VAR_vercel_token="$VERCEL_TOKEN"
export TF_VAR_vercel_team_id="$VERCEL_TEAM_ID"
export TF_VAR_claude_api_key="$CLAUDE_API_KEY"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan the deployment with variables from .env.local
echo "Planning Terraform deployment..."
terraform plan -var-file=terraform.tfvars

# Ask for confirmation
read -p "Do you want to apply these changes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Apply the changes with variables from .env.local
    echo "Applying Terraform changes..."
    terraform apply -var-file=terraform.tfvars -auto-approve
    
    echo "Deployment complete!"
    echo "The secrets will be created automatically in AWS Secrets Manager."
    echo "Your Batch jobs now have access to the required environment variables."
else
    echo "Deployment cancelled."
fi
