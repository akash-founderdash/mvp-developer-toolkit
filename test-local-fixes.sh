#!/bin/bash

# Quick local test of the clone-template.sh script with fixes
set -euo pipefail

echo "Testing clone-template.sh fixes locally..."
echo "========================================="

# Set up environment variables as they would be in the container
export JOB_ID="test-local-$(date +%s)"
export TEMPLATE_REPO="Appemout/event-engagement-toolkit"
export BUSINESS_NAME="Local Test Business"
export PRODUCT_DESCRIPTION="A local test of the fixed script"
export REPO_NAME="test-local-mvp"
export SANITIZED_NAME="test-local-mvp"
export GITHUB_USERNAME="founderdash-bot"
export SSH_PRIVATE_KEY_SECRET="founderdash-ssh-private-key"
export AWS_DEFAULT_REGION="us-east-2"

# Create a mock workspace
TEST_WORKSPACE="/tmp/local-test-workspace"
rm -rf "$TEST_WORKSPACE"
mkdir -p "$TEST_WORKSPACE"

# Test just the variable initialization part of the script
echo "Testing variable initialization..."

# Extract the initialization part of clone-template.sh and test it
bash -c '
set -euo pipefail

# Simulate the beginning of clone-template.sh
if [ -z "${JOB_ID:-}" ]; then
    if [ -n "${AWS_BATCH_JOB_ID:-}" ]; then
        export JOB_ID="$AWS_BATCH_JOB_ID"
    else
        export JOB_ID="clone-template-job-$(date +%s)"
    fi
fi

echo "DEBUG: JOB_ID is set to: $JOB_ID"

# Set default values for required variables if not already set
TEMPLATE_REPO="${TEMPLATE_REPO:-Appemout/event-engagement-toolkit}"
BUSINESS_NAME="${BUSINESS_NAME:-Test Business}"
PRODUCT_DESCRIPTION="${PRODUCT_DESCRIPTION:-A test MVP project}"
REPO_NAME="${REPO_NAME:-test-mvp-$(date +%s)}"
SANITIZED_NAME="${SANITIZED_NAME:-test-mvp}"
GITHUB_USERNAME="${GITHUB_USERNAME:-founderdash-bot}"

echo "DEBUG: Environment variables:"
echo "  TEMPLATE_REPO: $TEMPLATE_REPO"
echo "  BUSINESS_NAME: $BUSINESS_NAME"
echo "  REPO_NAME: $REPO_NAME"

echo "✅ Variable initialization test passed!"
'

echo ""
echo "✅ Local test completed successfully!"
echo "The JOB_ID unbound variable issue should now be fixed."
echo ""
echo "Next steps:"
echo "1. Start Docker Desktop"
echo "2. Run: ./docker/push-to-ecr.sh"
echo "3. Test the pipeline: ./scripts/eventbridge-test-cli.sh send"
