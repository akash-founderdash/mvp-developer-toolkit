#!/bin/bash

# EventBridge Quick Deploy Script
# This script helps you deploy the EventBridge infrastructure quickly

set -e  # Exit on any error

echo "🚀 EventBridge MVP Development - Quick Deploy"
echo "=============================================="
echo

# Check if we're in the right directory
if [ ! -d "infrastructure" ]; then
    echo "❌ Error: Please run this script from the root of the event-engagement-toolkit directory"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first:"
    echo "   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install it first:"
    echo "   https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi

echo "✅ AWS CLI and Terraform are installed"

# Check AWS credentials
echo "🔍 Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run:"
    echo "   aws configure"
    echo "   OR set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
echo "✅ AWS credentials configured"
echo "   Account ID: $AWS_ACCOUNT"
echo "   Region: $AWS_REGION"
echo

# Create terraform.tfvars if it doesn't exist
if [ ! -f "infrastructure/terraform.tfvars" ]; then
    echo "📝 Creating infrastructure/terraform.tfvars..."
    
    cat > infrastructure/terraform.tfvars << EOF
# EventBridge MVP Development Configuration
project_name = "founderdash-mvp"
aws_region = "$AWS_REGION"

# Container Configuration
container_image = "founderdash/mvp-pipeline:latest"

# GitHub Configuration (replace with your values)
github_token = "ghp_your_github_token_here"
github_username = "founderdash-bot"

# Vercel Configuration (replace with your values) 
vercel_token = "your_vercel_token_here"
vercel_team_id = "team_your_vercel_team_id_here"

# FounderDash Database URL (replace with your actual database)
founderdash_database_url = "postgresql://user:password@host:5432/founderdash"
EOF
    
    echo "✅ Created infrastructure/terraform.tfvars"
    echo "⚠️  Please edit this file with your actual tokens and database URL"
    echo
fi

# Ask user if they want to continue with deployment
echo "📋 Deployment Summary:"
echo "   Project Name: founderdash-mvp"
echo "   AWS Region: $AWS_REGION"
echo "   AWS Account: $AWS_ACCOUNT"
echo

# Check if terraform.tfvars has placeholder values
if grep -q "your_github_token_here\|your_vercel_token_here\|user:password@host" infrastructure/terraform.tfvars; then
    echo "⚠️  WARNING: terraform.tfvars contains placeholder values"
    echo "   Please update the following in infrastructure/terraform.tfvars:"
    echo "   - github_token: Your GitHub personal access token"
    echo "   - vercel_token: Your Vercel API token"  
    echo "   - founderdash_database_url: Your actual database URL"
    echo
    
    read -p "Do you want to edit terraform.tfvars now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Try to open with common editors
        if command -v code &> /dev/null; then
            code infrastructure/terraform.tfvars
        elif command -v nano &> /dev/null; then
            nano infrastructure/terraform.tfvars
        elif command -v vim &> /dev/null; then
            vim infrastructure/terraform.tfvars
        else
            echo "Please edit infrastructure/terraform.tfvars manually"
        fi
        
        echo "Press Enter when you've finished editing..."
        read
    fi
fi

read -p "Deploy EventBridge infrastructure? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Navigate to infrastructure directory
cd infrastructure

echo "🏗️  Initializing Terraform..."
terraform init

echo "🔍 Planning deployment..."
if ! terraform plan -out=tfplan; then
    echo "❌ Terraform plan failed. Please check the configuration."
    exit 1
fi

echo
echo "📋 Terraform will create the following resources:"
echo "   - EventBridge custom bus (mvp-development)"
echo "   - EventBridge rules and targets"
echo "   - DynamoDB table for job tracking"
echo "   - AWS Batch job definition and queue"
echo "   - IAM roles and policies"
echo "   - SNS topics and SQS queues"
echo

read -p "Apply this plan? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

echo "🚀 Deploying infrastructure..."
if terraform apply tfplan; then
    echo "✅ Infrastructure deployed successfully!"
    
    # Get outputs
    echo
    echo "📋 Deployment Information:"
    terraform output -json | jq -r '
    "   EventBridge Bus: " + .eventbridge_bus_name.value,
    "   EventBridge Bus ARN: " + .eventbridge_bus_arn.value,
    "   DynamoDB Table: " + .dynamodb_table_name.value,
    "   Batch Job Queue: " + .batch_job_queue_name.value
    '
    
    # Create environment file
    echo
    echo "📝 Creating .env.eventbridge file..."
    cd ..
    
    cat > .env.eventbridge << EOF
# EventBridge Configuration - Generated by deployment script
AWS_REGION=$AWS_REGION
EVENTBRIDGE_BUS_NAME=mvp-development
DYNAMODB_TABLE_NAME=mvp-development-jobs
FOUNDERDASH_DATABASE_URL=postgresql://user:password@host:5432/founderdash

# TODO: Add your actual AWS credentials
# AWS_ACCESS_KEY_ID=your_access_key_here
# AWS_SECRET_ACCESS_KEY=your_secret_key_here

# Optional: SNS Configuration
# SNS_COMPLETION_TOPIC_ARN=arn:aws:sns:$AWS_REGION:$AWS_ACCOUNT:mvp-completion
EOF
    
    echo "✅ Created .env.eventbridge"
    echo "⚠️  Please add your AWS credentials to .env.eventbridge"
    echo
    
    # Test the deployment
    echo "🧪 Testing EventBridge deployment..."
    
    export AWS_REGION=$AWS_REGION
    export EVENTBRIDGE_BUS_NAME=mvp-development
    export DYNAMODB_TABLE_NAME=mvp-development-jobs
    
    if node tooling/scripts/simple-eventbridge-test.js test-all; then
        echo "✅ EventBridge deployment test passed!"
        echo
        echo "🎉 Deployment Complete!"
        echo "   You can now send MVP development events to EventBridge"
        echo
        echo "Next steps:"
        echo "   1. Update .env.eventbridge with your AWS credentials"
        echo "   2. Test sending events: node tooling/scripts/simple-eventbridge-test.js send"
        echo "   3. Integrate with your FounderDash app using the API endpoints"
    else
        echo "⚠️  EventBridge deployment completed but tests failed"
        echo "   Please check your AWS credentials and configuration"
    fi
    
else
    echo "❌ Deployment failed. Please check the errors above."
    rm -f tfplan
    exit 1
fi

rm -f tfplan
