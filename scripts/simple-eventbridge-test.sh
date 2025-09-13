#!/bin/bash

# Simple EventBridge Test Script
# Tests the complete MVP development workflow

set -e

# Configuration
REGION="us-east-2"
EVENT_BUS_NAME="mvp-development"
DYNAMODB_TABLE="mvp-pipeline-development-jobs"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "EventBridge MVP Development Test"
echo "================================"
echo
echo "Region: $REGION"
echo "EventBridge Bus: $EVENT_BUS_NAME" 
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo

# Generate test job ID
JOB_ID="test_job_$(date +%s)_$(openssl rand -hex 4 2>/dev/null || echo "$(date +%N)" | tail -c 8)"

echo "🚀 Sending test MVP development event..."
echo "Job ID: $JOB_ID"

# Create DynamoDB record first
echo -e "${BLUE}📝 Creating DynamoDB job record...${NC}"
CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

aws dynamodb put-item \
    --table-name "$DYNAMODB_TABLE" \
    --region "$REGION" \
    --item "{
        \"jobId\": {\"S\": \"$JOB_ID\"},
        \"userId\": {\"S\": \"test_user_123\"},
        \"productId\": {\"S\": \"test_product_456\"},
        \"businessName\": {\"S\": \"Test Business MVP\"},
        \"status\": {\"S\": \"PENDING\"},
        \"createdAt\": {\"S\": \"$CURRENT_TIME\"},
        \"updatedAt\": {\"S\": \"$CURRENT_TIME\"}
    }"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DynamoDB record created${NC}"
else
    echo -e "${RED}❌ Failed to create DynamoDB record${NC}"
    exit 1
fi

# Send EventBridge event
echo -e "${BLUE}🎯 Sending EventBridge event...${NC}"

aws events put-events \
    --region "$REGION" \
    --entries '[{
        "Source": "founderdash.web",
        "DetailType": "MVP Development Request",
        "Detail": "{\"jobId\": \"'$JOB_ID'\", \"userId\": \"test_user_123\", \"businessName\": \"Test Business MVP\"}",
        "EventBusName": "'$EVENT_BUS_NAME'"
    }]'

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ EventBridge event sent successfully${NC}"
    echo
    echo "🎉 Test completed successfully!"
    echo "   • Job ID: $JOB_ID"
    echo "   • Check AWS Batch console to see if job was triggered"
    echo "   • Check DynamoDB table for job status updates"
    echo
    echo "You can query the job status with:"
    echo "   aws dynamodb get-item --table-name $DYNAMODB_TABLE --key '{\"jobId\":{\"S\":\"$JOB_ID\"}}' --region $REGION"
else
    echo -e "${RED}❌ Failed to send EventBridge event${NC}"
    exit 1
fi
