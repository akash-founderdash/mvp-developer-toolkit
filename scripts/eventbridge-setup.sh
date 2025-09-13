#!/bin/bash

# EventBridge MVP Development Setup Script
# This script helps set up and test the EventBridge MVP development system

set -e

echo "🚀 EventBridge MVP Development Setup"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first:"
        echo "  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    print_status "AWS CLI found"
}

# Check if Terraform is installed (optional)
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform not found. Install it to deploy infrastructure automatically."
        echo "  https://learn.hashicorp.com/tutorials/terraform/install-cli"
        return 1
    fi
    print_status "Terraform found"
    return 0
}

# Check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi
    
    local identity=$(aws sts get-caller-identity --output text --query 'Account')
    print_status "AWS credentials configured (Account: $identity)"
}

# Create environment file
create_env_file() {
    if [ ! -f ".env.eventbridge" ]; then
        print_status "Creating .env.eventbridge file..."
        
        local aws_region=$(aws configure get region || echo "us-east-1")
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        
        cat > .env.eventbridge << EOF
# EventBridge Configuration for MVP Development
# Generated on $(date)

# AWS Configuration
AWS_REGION=$aws_region
# AWS_ACCESS_KEY_ID=your_access_key_here  # Use AWS credentials file instead
# AWS_SECRET_ACCESS_KEY=your_secret_key_here

# EventBridge Settings
EVENTBRIDGE_BUS_NAME=mvp-development
EVENTBRIDGE_SOURCE=founderdash.web
EVENTBRIDGE_DETAIL_TYPE=MVP Development Request

# DynamoDB Settings
DYNAMODB_TABLE_NAME=mvp-development-jobs
DYNAMODB_REGION=$aws_region

# FounderDash Database (UPDATE THIS)
FOUNDERDASH_DATABASE_URL=postgresql://username:password@localhost:5432/founderdash

# AWS Account Info
AWS_ACCOUNT_ID=$account_id

# Optional: SNS Settings for notifications
SNS_COMPLETION_TOPIC_ARN=arn:aws:sns:$aws_region:$account_id:mvp-completion

# Optional: AWS Batch Settings (for reference)
BATCH_JOB_QUEUE=mvp-pipeline-job-queue
BATCH_JOB_DEFINITION=mvp-pipeline-job

# Development/Testing flags
ENABLE_DEBUG_LOGGING=true
TEST_MODE=false
EOF
        
        print_status "Environment file created: .env.eventbridge"
        print_warning "Please update FOUNDERDASH_DATABASE_URL in .env.eventbridge"
    else
        print_status "Environment file already exists: .env.eventbridge"
    fi
}

# Load environment variables
load_env() {
    if [ -f ".env.eventbridge" ]; then
        export $(cat .env.eventbridge | grep -v '^#' | xargs)
        print_status "Environment variables loaded"
    else
        print_error "Environment file not found. Run setup first."
        exit 1
    fi
}

# Check if infrastructure exists
check_infrastructure() {
    echo ""
    echo "🔍 Checking AWS Infrastructure..."
    
    # Check EventBridge bus
    if aws events describe-event-bus --name "${EVENTBRIDGE_BUS_NAME}" &> /dev/null; then
        print_status "EventBridge bus '${EVENTBRIDGE_BUS_NAME}' exists"
    else
        print_warning "EventBridge bus '${EVENTBRIDGE_BUS_NAME}' does not exist"
        echo "   Deploy infrastructure: cd infrastructure && terraform apply"
    fi
    
    # Check DynamoDB table
    if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE_NAME}" &> /dev/null; then
        print_status "DynamoDB table '${DYNAMODB_TABLE_NAME}' exists"
    else
        print_warning "DynamoDB table '${DYNAMODB_TABLE_NAME}' does not exist"
        echo "   Deploy infrastructure: cd infrastructure && terraform apply"
    fi
    
    # Check Batch job queue
    if aws batch describe-job-queues --job-queues "${BATCH_JOB_QUEUE}" &> /dev/null; then
        print_status "Batch job queue '${BATCH_JOB_QUEUE}' exists"
    else
        print_warning "Batch job queue '${BATCH_JOB_QUEUE}' does not exist"
        echo "   Deploy infrastructure: cd infrastructure && terraform apply"
    fi
}

# Deploy infrastructure
deploy_infrastructure() {
    if ! check_terraform; then
        print_error "Terraform required for infrastructure deployment"
        exit 1
    fi
    
    if [ ! -d "infrastructure" ]; then
        print_error "Infrastructure directory not found"
        exit 1
    fi
    
    echo ""
    echo "🚀 Deploying Infrastructure..."
    
    cd infrastructure
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Plan
    print_status "Planning infrastructure changes..."
    terraform plan -out=tfplan
    
    # Apply with confirmation
    read -p "Deploy infrastructure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Applying infrastructure changes..."
        terraform apply tfplan
        print_status "Infrastructure deployed successfully!"
    else
        print_warning "Infrastructure deployment cancelled"
    fi
    
    cd ..
}

# Test EventBridge
test_eventbridge() {
    echo ""
    echo "🧪 Testing EventBridge..."
    
    if [ -f "tooling/scripts/simple-eventbridge-test.js" ]; then
        # Test connections
        node tooling/scripts/simple-eventbridge-test.js test-all
        
        echo ""
        read -p "Send a test MVP development event? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            node tooling/scripts/simple-eventbridge-test.js send
        fi
    else
        print_error "Test script not found: tooling/scripts/simple-eventbridge-test.js"
    fi
}

# Install dependencies
install_dependencies() {
    echo ""
    echo "📦 Installing Dependencies..."
    
    if [ -f "package.json" ]; then
        if command -v pnpm &> /dev/null; then
            pnpm install
        elif command -v npm &> /dev/null; then
            npm install
        else
            print_error "Neither pnpm nor npm found"
            exit 1
        fi
        print_status "Dependencies installed"
    else
        print_warning "No package.json found in root directory"
    fi
    
    # Install API package dependencies
    if [ -d "packages/api" ]; then
        cd packages/api
        if command -v pnpm &> /dev/null; then
            pnpm install
        else
            npm install
        fi
        cd ../..
        print_status "API package dependencies installed"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "Choose an action:"
    echo "1) Full setup (recommended for first time)"
    echo "2) Create environment file"
    echo "3) Check infrastructure"
    echo "4) Deploy infrastructure"
    echo "5) Test EventBridge"
    echo "6) Install dependencies"
    echo "7) Exit"
    echo ""
    read -p "Enter your choice (1-7): " choice
    
    case $choice in
        1)
            full_setup
            ;;
        2)
            create_env_file
            ;;
        3)
            load_env
            check_infrastructure
            ;;
        4)
            load_env
            deploy_infrastructure
            ;;
        5)
            load_env
            test_eventbridge
            ;;
        6)
            install_dependencies
            ;;
        7)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            show_menu
            ;;
    esac
}

# Full setup
full_setup() {
    echo ""
    echo "🚀 Running Full Setup..."
    
    check_aws_cli
    check_aws_credentials
    create_env_file
    load_env
    install_dependencies
    check_infrastructure
    
    echo ""
    print_status "Setup complete!"
    print_warning "Next steps:"
    echo "1. Update FOUNDERDASH_DATABASE_URL in .env.eventbridge"
    echo "2. Deploy infrastructure if needed: ./eventbridge-setup.sh (option 4)"
    echo "3. Test EventBridge: ./eventbridge-setup.sh (option 5)"
}

# Script entry point
main() {
    if [ "$1" = "setup" ] || [ "$1" = "--setup" ]; then
        full_setup
    elif [ "$1" = "deploy" ] || [ "$1" = "--deploy" ]; then
        check_aws_cli
        check_aws_credentials
        load_env
        deploy_infrastructure
    elif [ "$1" = "test" ] || [ "$1" = "--test" ]; then
        check_aws_cli
        check_aws_credentials
        load_env
        test_eventbridge
    elif [ "$1" = "check" ] || [ "$1" = "--check" ]; then
        check_aws_cli
        check_aws_credentials
        load_env
        check_infrastructure
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "EventBridge MVP Development Setup Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup    Run full setup (interactive)"
        echo "  deploy   Deploy infrastructure"
        echo "  test     Test EventBridge functionality"
        echo "  check    Check existing infrastructure"
        echo "  --help   Show this help message"
        echo ""
        echo "Without arguments, shows interactive menu."
    else
        show_menu
    fi
}

# Run main function
main "$@"
