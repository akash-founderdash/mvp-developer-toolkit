#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 MVP EventBridge System Setup${NC}"
echo -e "${BLUE}==============================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI first.${NC}"
    echo -e "${YELLOW}💡 Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html${NC}"
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform first.${NC}"
    echo -e "${YELLOW}💡 Visit: https://developer.hashicorp.com/terraform/downloads${NC}"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
    echo -e "${YELLOW}💡 Visit: https://docs.docker.com/get-docker/${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites found${NC}"

# Check AWS credentials
echo ""
echo -e "${YELLOW}🔐 Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured or invalid.${NC}"
    echo -e "${YELLOW}💡 Run: aws configure${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
echo -e "Account ID: ${GREEN}$ACCOUNT_ID${NC}"
echo -e "Current User: ${GREEN}$CURRENT_USER${NC}"

# Initialize Terraform
echo ""
echo -e "${YELLOW}🏗️ Initializing Terraform...${NC}"
cd infrastructure

if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}📝 Creating terraform.tfvars from template...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${YELLOW}💡 Please edit terraform.tfvars with your specific values before deploying.${NC}"
fi

terraform init

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Terraform initialized successfully${NC}"
else
    echo -e "${RED}❌ Terraform initialization failed${NC}"
    exit 1
fi

# Validate Terraform configuration
echo ""
echo -e "${YELLOW}✅ Validating Terraform configuration...${NC}"
terraform validate

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Terraform configuration is valid${NC}"
else
    echo -e "${RED}❌ Terraform configuration validation failed${NC}"
    exit 1
fi

# Make scripts executable
echo ""
echo -e "${YELLOW}🔧 Setting up scripts...${NC}"
cd ..
chmod +x scripts/*.sh
chmod +x docker/*.sh

echo -e "${GREEN}✅ Scripts are now executable${NC}"

# Setup complete
echo ""
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo -e "1. ${YELLOW}Edit infrastructure/terraform.tfvars${NC} with your specific values"
echo -e "2. ${YELLOW}Deploy infrastructure:${NC} make deploy"
echo -e "3. ${YELLOW}Build and push container:${NC} make container"
echo -e "4. ${YELLOW}Test the system:${NC} make test"
echo ""
echo -e "${BLUE}📚 Available Commands:${NC}"
echo -e "  ${YELLOW}make help${NC}        - Show all available commands"
echo -e "  ${YELLOW}make deploy${NC}      - Deploy infrastructure"
echo -e "  ${YELLOW}make container${NC}   - Build and push container"
echo -e "  ${YELLOW}make test${NC}        - Run system tests"
echo -e "  ${YELLOW}make status${NC}      - Check system status"
echo -e "  ${YELLOW}make clean${NC}       - Destroy infrastructure"
echo ""
echo -e "${GREEN}🚀 Happy developing!${NC}"
