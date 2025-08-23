#!/bin/bash

set -euo pipefail

echo "=== DEBUG: Testing environment loading ==="

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo "Error: .env.local file not found!"
    exit 1
fi

echo "Loading .env.local..."

# Load environment variables from .env.local using a more robust method
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # Export valid variable assignments
    if [[ $line =~ ^[A-Z_][A-Z0-9_]*= ]]; then
        echo "Processing line: $line"
        export "$line"
    fi
done < .env.local

echo ""
echo "=== Variables after loading ==="
echo "GITHUB_TOKEN: ${GITHUB_TOKEN:-NOT_SET}"
echo "VERCEL_TOKEN: ${VERCEL_TOKEN:-NOT_SET}" 
echo "VERCEL_TEAM_ID: ${VERCEL_TEAM_ID:-NOT_SET}"
echo "CLAUDE_API_KEY: ${CLAUDE_API_KEY:-NOT_SET}"

echo ""
echo "=== TF_VAR variables ==="
export TF_VAR_github_token="$GITHUB_TOKEN"
export TF_VAR_vercel_token="$VERCEL_TOKEN"
export TF_VAR_vercel_team_id="$VERCEL_TEAM_ID"
export TF_VAR_claude_api_key="$CLAUDE_API_KEY"

echo "TF_VAR_github_token: ${TF_VAR_github_token:-NOT_SET}"
echo "TF_VAR_vercel_token: ${TF_VAR_vercel_token:-NOT_SET}"
echo "TF_VAR_vercel_team_id: ${TF_VAR_vercel_team_id:-NOT_SET}"
echo "TF_VAR_claude_api_key: ${TF_VAR_claude_api_key:-NOT_SET}"

echo ""
echo "=== Testing Terraform plan ==="
cd infrastructure
terraform plan -var-file=terraform.tfvars
