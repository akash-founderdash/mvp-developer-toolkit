#!/bin/bash

# Local test script using your existing SSH keys
set -euo pipefail

echo "Testing clone-template.sh with local SSH keys..."
echo "================================================"

# Set up test environment variables
export JOB_ID="test-job-$(date +%s)"
export TEMPLATE_REPO="Appemout/event-engagement-toolkit"
export BUSINESS_NAME="Test Business Local"
export PRODUCT_DESCRIPTION="A test MVP for validating the clone template functionality with local SSH"
export REPO_NAME="test-mvp-local-$(date +%s)"
export SANITIZED_NAME="test-mvp-local"
export GITHUB_USERNAME="test-user"

echo "Test Environment:"
echo "- JOB_ID: $JOB_ID"
echo "- TEMPLATE_REPO: $TEMPLATE_REPO"
echo "- BUSINESS_NAME: $BUSINESS_NAME"
echo "- REPO_NAME: $REPO_NAME"
echo ""

# Check if SSH keys exist
if [ -f ~/.ssh/id_ed25519 ]; then
    echo "✅ Found Ed25519 SSH key: ~/.ssh/id_ed25519"
elif [ -f ~/.ssh/id_rsa ]; then
    echo "✅ Found RSA SSH key: ~/.ssh/id_rsa"
else
    echo "❌ No SSH keys found in ~/.ssh/"
    exit 1
fi

# Test SSH connectivity to GitHub
echo ""
echo "Testing SSH connectivity to GitHub..."
if ssh -T git@github.com -o ConnectTimeout=10 -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ SSH authentication to GitHub successful"
    
    echo ""
    echo "Testing template repository access via SSH..."
    if git ls-remote --heads "git@github.com:$TEMPLATE_REPO.git" > /dev/null 2>&1; then
        echo "✅ Template repository is accessible via SSH: $TEMPLATE_REPO"
        
        echo ""
        echo "🚀 Testing actual clone operation..."
        
        # Create test workspace
        TEST_WORKSPACE="/tmp/mvp-test-workspace-ssh"
        rm -rf "$TEST_WORKSPACE"
        mkdir -p "$TEST_WORKSPACE"
        
        # Test clone
        if git clone --depth 1 "git@github.com:$TEMPLATE_REPO.git" "$TEST_WORKSPACE/template"; then
            echo "✅ Successfully cloned template repository!"
            echo "Repository contents:"
            ls -la "$TEST_WORKSPACE/template/" | head -10
            
            # Cleanup
            rm -rf "$TEST_WORKSPACE"
        else
            echo "❌ Failed to clone template repository"
        fi
        
    else
        echo "❌ Template repository is NOT accessible via SSH: $TEMPLATE_REPO"
        echo "This could mean:"
        echo "  - Repository doesn't exist at this path"
        echo "  - Repository is private and your SSH key doesn't have access"
    fi
else
    echo "❌ SSH authentication to GitHub failed"
    echo "Your SSH key might not be added to your GitHub account"
    echo ""
    echo "To add your SSH key to GitHub:"
    echo "1. Copy your public key:"
    if [ -f ~/.ssh/id_ed25519.pub ]; then
        echo "   cat ~/.ssh/id_ed25519.pub"
    elif [ -f ~/.ssh/id_rsa.pub ]; then
        echo "   cat ~/.ssh/id_rsa.pub"
    fi
    echo "2. Go to GitHub Settings > SSH and GPG keys"
    echo "3. Add your public key"
fi

echo ""
echo "For AWS Batch environment:"
echo "1. Store your private key in AWS Secrets Manager"
echo "2. Set SSH_PRIVATE_KEY_SECRET environment variable"
echo "3. The script will automatically configure SSH authentication"
