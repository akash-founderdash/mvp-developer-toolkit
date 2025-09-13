#!/bin/bash

# Script to upload SSH private key to AWS Secrets Manager
set -euo pipefail

echo "SSH Key Setup for AWS Secrets Manager"
echo "===================================="

# Configuration
SECRET_NAME="${1:-founderdash-ssh-private-key}"
REGION="${AWS_DEFAULT_REGION:-us-east-2}"

echo "Secret Name: $SECRET_NAME"
echo "Region: $REGION"
echo ""

# Check if SSH key exists
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "❌ SSH private key not found at ~/.ssh/id_ed25519"
    exit 1
fi

echo "✅ Found SSH private key: ~/.ssh/id_ed25519"

# Display public key for reference
echo ""
echo "📋 Your public key (add this to GitHub if not already done):"
echo "--------------------------------------------------------"
cat ~/.ssh/id_ed25519.pub
echo ""
echo "To add to GitHub:"
echo "1. Go to https://github.com/settings/keys"
echo "2. Click 'New SSH key'"
echo "3. Paste the above public key"
echo ""

# Check if secret already exists
echo "🔍 Checking if secret already exists..."
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "⚠️  Secret '$SECRET_NAME' already exists"
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 0
    fi
    
    # Update existing secret
    echo "🔄 Updating existing secret..."
    if aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string file://~/.ssh/id_ed25519 \
        --region "$REGION" >/dev/null; then
        echo "✅ SSH private key updated in AWS Secrets Manager"
    else
        echo "❌ Failed to update secret"
        exit 1
    fi
else
    # Create new secret
    echo "📤 Uploading SSH private key to AWS Secrets Manager..."
    if aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "SSH private key for GitHub access (FounderDash MVP Pipeline)" \
        --secret-string file://~/.ssh/id_ed25519 \
        --region "$REGION" >/dev/null; then
        echo "✅ SSH private key stored in AWS Secrets Manager"
    else
        echo "❌ Failed to create secret"
        exit 1
    fi
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Set environment variable in your AWS Batch job definition:"
echo "   SSH_PRIVATE_KEY_SECRET=$SECRET_NAME"
echo ""
echo "2. Or update your Terraform configuration:"
echo "   environment {"
echo "     name  = \"SSH_PRIVATE_KEY_SECRET\""
echo "     value = \"$SECRET_NAME\""
echo "   }"
echo ""
echo "3. Test the pipeline:"
echo "   ./scripts/eventbridge-test-cli.sh send"
