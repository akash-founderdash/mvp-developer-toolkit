#!/bin/bash

set -e

# Configuration
REGION=${AWS_REGION:-"us-east-2"}
REPOSITORY_NAME="founderdash/mvp-pipeline"
IMAGE_TAG=${IMAGE_TAG:-"latest"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 Building and Pushing MVP Pipeline Container${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Get AWS account ID
echo -e "${YELLOW}📋 Getting AWS account information...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Failed to get AWS account ID. Please check AWS credentials.${NC}"
    exit 1
fi

echo -e "Account ID: ${GREEN}$ACCOUNT_ID${NC}"
echo -e "Region: ${GREEN}$REGION${NC}"
echo -e "Repository: ${GREEN}$REPOSITORY_NAME${NC}"
echo ""

# Construct ECR repository URI
ECR_REPOSITORY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME"
FULL_IMAGE_NAME="$ECR_REPOSITORY:$IMAGE_TAG"

echo -e "${YELLOW}🔐 Logging into ECR...${NC}"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully logged into ECR${NC}"
else
    echo -e "${RED}❌ Failed to login to ECR${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🏗️ Building Docker image...${NC}"
docker build -t $REPOSITORY_NAME:$IMAGE_TAG docker/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Docker image built successfully${NC}"
else
    echo -e "${RED}❌ Failed to build Docker image${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🏷️ Tagging image for ECR...${NC}"
docker tag $REPOSITORY_NAME:$IMAGE_TAG $FULL_IMAGE_NAME

echo ""
echo -e "${YELLOW}📤 Pushing image to ECR...${NC}"
echo -e "Pushing: ${BLUE}$FULL_IMAGE_NAME${NC}"

docker push $FULL_IMAGE_NAME

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully pushed image to ECR${NC}"
    echo ""
    echo -e "${GREEN}🎉 Container deployment complete!${NC}"
    echo ""
    echo -e "Image URI: ${BLUE}$FULL_IMAGE_NAME${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo -e "1. Update job definition with new image URI"
    echo -e "2. Test the deployment with: make test"
    echo -e "3. Monitor job execution in AWS Batch"
else
    echo -e "${RED}❌ Failed to push image to ECR${NC}"
    exit 1
fi
