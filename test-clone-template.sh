#!/bin/bash

# Test script for clone-template.sh
set -euo pipefail

echo "Testing clone-template.sh script..."
echo "================================="

# Set up test environment variables
export JOB_ID="test-job-$(date +%s)"
export TEMPLATE_REPO="Appemout/event-engagement-toolkit"
export BUSINESS_NAME="Test Business"
export PRODUCT_DESCRIPTION="A test MVP for validating the clone template functionality"
export REPO_NAME="test-mvp-$(date +%s)"
export SANITIZED_NAME="test-mvp"
export GITHUB_USERNAME="test-user"

# Note: You'll need to set these for authentication testing
# export GITHUB_TOKEN_SECRET="your-secret-name-in-aws-secrets-manager"
# export AWS_DEFAULT_REGION="us-east-2"

echo "Test Environment:"
echo "- JOB_ID: $JOB_ID"
echo "- TEMPLATE_REPO: $TEMPLATE_REPO"
echo "- BUSINESS_NAME: $BUSINESS_NAME"
echo "- REPO_NAME: $REPO_NAME"
echo ""

# Create test workspace
TEST_WORKSPACE="/tmp/mvp-test-workspace"
rm -rf "$TEST_WORKSPACE"
mkdir -p "$TEST_WORKSPACE"

echo "Test workspace created at: $TEST_WORKSPACE"
echo ""

# Test just the SSH connectivity and repository access
echo "Testing SSH connectivity to GitHub..."
if ssh -T git@github.com -o ConnectTimeout=5 -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ SSH authentication to GitHub successful"
    
    echo "Testing template repository access via SSH..."
    if git ls-remote --heads "git@github.com:$TEMPLATE_REPO.git" > /dev/null 2>&1; then
        echo "✅ Template repository is accessible via SSH: $TEMPLATE_REPO"
    else
        echo "❌ Template repository is NOT accessible via SSH: $TEMPLATE_REPO"
        echo "This could mean:"
        echo "  - Repository doesn't exist"
        echo "  - Repository is private and SSH key doesn't have access"
        echo "  - SSH key is not properly configured"
    fi
else
    echo "❌ SSH authentication to GitHub failed"
    echo "This could mean:"
    echo "  - No SSH key is configured"
    echo "  - SSH key is not added to GitHub account"
    echo "  - Network connectivity issues"
    
    echo ""
    echo "Testing template repository access via HTTPS (fallback)..."
    if git ls-remote --heads "https://github.com/$TEMPLATE_REPO.git" > /dev/null 2>&1; then
        echo "✅ Template repository is accessible via HTTPS: $TEMPLATE_REPO"
        echo "Repository exists but requires authentication for SSH access"
    else
        echo "❌ Template repository is NOT accessible via HTTPS either: $TEMPLATE_REPO"
        echo "Repository might not exist or might be private"
    fi
fi

echo ""
echo "To test the full script with authentication:"
echo "1. Set up AWS credentials"
echo "2. Set GITHUB_TOKEN_SECRET environment variable"
echo "3. Run: ./docker/scripts/clone-template.sh"
echo ""
echo "Or monitor the AWS Batch job logs after triggering via EventBridge"
