#!/bin/bash

set -euo pipefail

echo "Note: This script is no longer needed!"
echo "Secrets are now managed automatically by Terraform."
echo ""
echo "To deploy your infrastructure with secrets:"
echo "1. Make sure your tokens are set in .env.local"
echo "2. Run ./deploy-infrastructure.sh"
echo ""
echo "The deployment script will automatically:"
echo "- Load tokens from .env.local"
echo "- Create AWS Secrets Manager secrets via Terraform"
echo "- Deploy the complete infrastructure"

# Create or update Vercel token secret
echo "Creating Vercel token secret..."
aws secretsmanager create-secret \
    --name "$VERCEL_TOKEN_SECRET_NAME" \
    --description "Vercel API token for MVP pipeline" \
    --secret-string "$VERCEL_TOKEN" \
    --region "$REGION" 2>/dev/null || \
aws secretsmanager update-secret \
    --secret-id "$VERCEL_TOKEN_SECRET_NAME" \
    --secret-string "$VERCEL_TOKEN" \
    --region "$REGION"

# Create or update Claude API key secret
echo "Creating Claude API key secret..."
aws secretsmanager create-secret \
    --name "$CLAUDE_API_KEY_SECRET_NAME" \
    --description "Claude API key for MVP pipeline" \
    --secret-string "$CLAUDE_API_KEY" \
    --region "$REGION" 2>/dev/null || \
aws secretsmanager update-secret \
    --secret-id "$CLAUDE_API_KEY_SECRET_NAME" \
    --secret-string "$CLAUDE_API_KEY" \
    --region "$REGION"

echo "All secrets created/updated successfully!"
echo "Now run 'terraform apply' to update your Batch job definition with the correct environment variables."
