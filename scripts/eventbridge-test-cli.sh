#!/bin/bash

# Simple EventBridge Test Script using AWS CLI
# No additional dependencies required - just AWS CLI

set -e

# Configuration
REGION=${AWS_REGION:-"us-east-2"}
EVENT_BUS_NAME=${EVENTBRIDGE_BUS_NAME:-"mvp-development"}
DYNAMODB_TABLE=${DYNAMODB_TABLE_NAME:-"mvp-pipeline-development-jobs"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}EventBridge MVP Development Test${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "Region: ${YELLOW}$REGION${NC}"
echo -e "EventBridge Bus: ${YELLOW}$EVENT_BUS_NAME${NC}"
echo -e "DynamoDB Table: ${YELLOW}$DYNAMODB_TABLE${NC}"
echo ""

# Function to test DynamoDB
test_dynamodb() {
    echo -e "${BLUE}🔍 Testing DynamoDB connection...${NC}"
    
    if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DynamoDB table '$DYNAMODB_TABLE' exists${NC}"
        
        # Get table info
        TABLE_STATUS=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'Table.TableStatus' --output text)
        ITEM_COUNT=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" --query 'Table.ItemCount' --output text 2>/dev/null || echo "0")
        
        echo -e "   Status: ${GREEN}$TABLE_STATUS${NC}"
        echo -e "   Items: ${YELLOW}$ITEM_COUNT${NC}"
        return 0
    else
        echo -e "${RED}❌ DynamoDB table '$DYNAMODB_TABLE' does not exist${NC}"
        echo -e "${YELLOW}💡 Run: terraform apply to create the table${NC}"
        return 1
    fi
}

# Function to test EventBridge
test_eventbridge() {
    echo -e "${BLUE}🔍 Testing EventBridge connection...${NC}"
    
    if aws events describe-event-bus --name "$EVENT_BUS_NAME" --region "$REGION" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ EventBridge bus '$EVENT_BUS_NAME' exists${NC}"
        
        # Get bus ARN
        BUS_ARN=$(aws events describe-event-bus --name "$EVENT_BUS_NAME" --region "$REGION" --query 'Arn' --output text)
        echo -e "   ARN: ${YELLOW}$BUS_ARN${NC}"
        
        # List rules
        echo -e "${BLUE}📋 EventBridge rules:${NC}"
        aws events list-rules --event-bus-name "$EVENT_BUS_NAME" --region "$REGION" --query 'Rules[].{Name:Name,State:State}' --output table
        
        return 0
    else
        echo -e "${RED}❌ EventBridge bus '$EVENT_BUS_NAME' does not exist${NC}"
        echo -e "${YELLOW}💡 Run: terraform apply to create the EventBridge bus${NC}"
        return 1
    fi
}

# Function to send test event
send_test_event() {
    echo -e "${BLUE}🚀 Sending test MVP development event...${NC}"
    
    # Generate job ID
    TIMESTAMP=$(date +%s)
    RANDOM_SUFFIX=$(openssl rand -hex 4 2>/dev/null || echo "$(date +%N | cut -c1-8)")
    JOB_ID="test_job_${TIMESTAMP}_${RANDOM_SUFFIX}"
    
    echo -e "Job ID: ${YELLOW}$JOB_ID${NC}"
    
    # Create DynamoDB record first
    echo -e "${BLUE}📝 Creating DynamoDB job record...${NC}"
    
    CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    ESTIMATED_COMPLETION=$(date -u -d "+4 hours" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -v+4H +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || echo "$CURRENT_TIME")
    
    # Create temp directory if it doesn't exist
    mkdir -p /tmp
    
    cat > /tmp/job-record.json << EOF
{
    "jobId": "$JOB_ID",
    "userId": "test_user_123",
    "productId": "test_product_456",
    "businessName": "Test Business MVP",
    "status": "PENDING",
    "currentStep": "QUEUED",
    "progress": 0,
    "timestamps": {
        "createdAt": "$CURRENT_TIME",
        "startedAt": null,
        "estimatedCompletion": "$ESTIMATED_COMPLETION",
        "completedAt": null
    },
    "resources": {
        "batchJobId": null,
        "githubRepo": {
            "name": "test-business-mvp",
            "url": null,
            "branch": "main"
        },
        "vercel": {
            "projectId": null,
            "deploymentId": null
        }
    },
    "urls": {
        "codeRepository": null,
        "staging": null,
        "production": null
    },
    "errors": [],
    "executionLogs": [],
    "metadata": {
        "testEvent": true,
        "priority": "normal",
        "requestedFeatures": ["authentication", "dashboard", "payments"]
    }
}
EOF

    if aws dynamodb put-item --table-name "$DYNAMODB_TABLE" --region "$REGION" --item '{
        "jobId": {"S": "'$JOB_ID'"},
        "userId": {"S": "test_user_123"},
        "productId": {"S": "test_product_456"},
        "businessName": {"S": "Test Business MVP"},
        "status": {"S": "PENDING"},
        "createdAt": {"S": "'$CURRENT_TIME'"},
        "updatedAt": {"S": "'$CURRENT_TIME'"},
        "estimatedCompletion": {"S": "'$ESTIMATED_COMPLETION'"},
        "githubRepo": {"S": ""},
        "vercelUrl": {"S": ""},
        "metadata": {"M": {
            "testEvent": {"BOOL": true},
            "priority": {"S": "normal"},
            "requestedFeatures": {"SS": ["authentication", "dashboard", "payments"]}
        }}
    }'; then
        echo -e "${GREEN}✅ DynamoDB record created${NC}"
    else
        echo -e "${RED}❌ Failed to create DynamoDB record${NC}"
        return 1
    fi
    
    # Create EventBridge event
    echo -e "${BLUE}📤 Sending EventBridge event...${NC}"
    
    # Send event directly with inline JSON to avoid file path issues
    if RESULT=$(aws events put-events --region "$REGION" --entries '[
        {
            "Source": "founderdash.web",
            "DetailType": "MVP Development Request",
            "Detail": "{\"jobId\": \"'$JOB_ID'\", \"userId\": \"test_user_123\", \"productId\": \"test_product_456\", \"priority\": \"normal\", \"timestamp\": \"'$CURRENT_TIME'\", \"metadata\": {\"businessName\": \"Test Business MVP\", \"estimatedDuration\": 14400, \"features\": [\"authentication\", \"dashboard\", \"payments\"], \"testEvent\": true, \"generatedBy\": \"bash-test-script\"}}",
            "EventBusName": "'$EVENT_BUS_NAME'"
        }
    ]' 2>&1); then
        EVENT_ID=$(echo "$RESULT" | jq -r '.Entries[0].EventId // "unknown"')
        FAILED_COUNT=$(echo "$RESULT" | jq -r '.FailedEntryCount // 0')
        
        if [ "$FAILED_COUNT" -eq 0 ]; then
            echo -e "${GREEN}✅ EventBridge event sent successfully!${NC}"
            echo -e "   Job ID: ${YELLOW}$JOB_ID${NC}"
            echo -e "   Event ID: ${YELLOW}$EVENT_ID${NC}"
            echo ""
            echo -e "${BLUE}💡 Next steps:${NC}"
            echo -e "   1. Check AWS Batch for job execution:"
            echo -e "      ${YELLOW}aws batch list-jobs --job-queue mvp-pipeline-job-queue --region $REGION${NC}"
            echo -e "   2. Monitor job status in DynamoDB:"
            echo -e "      ${YELLOW}aws dynamodb get-item --table-name $DYNAMODB_TABLE --key '{\"jobId\": {\"S\": \"$JOB_ID\"}}' --region $REGION${NC}"
            echo -e "   3. Check CloudWatch logs for EventBridge execution"
        else
            echo -e "${RED}❌ EventBridge event failed${NC}"
            echo "$RESULT" | jq '.Entries[] | select(.ErrorCode) | {ErrorCode, ErrorMessage}'
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to send EventBridge event${NC}"
        echo "$RESULT"
        return 1
    fi
    
    # Cleanup temp files
    rm -f /tmp/job-record.json /tmp/event-detail.json /tmp/event-entry.json
}

# Function to query job status
query_job_status() {
    local job_id="$1"
    if [ -z "$job_id" ]; then
        echo -e "${RED}❌ Job ID required${NC}"
        echo "Usage: $0 query-job JOB_ID"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Querying job status: $job_id${NC}"
    
    if RESULT=$(aws dynamodb get-item --table-name "$DYNAMODB_TABLE" --key "{\"jobId\": {\"S\": \"$job_id\"}}" --region "$REGION" 2>&1); then
        if echo "$RESULT" | jq -e '.Item' >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Job found${NC}"
            echo "$RESULT" | jq -r '.Item | {
                jobId: .jobId.S,
                status: .status.S,
                currentStep: .currentStep.S,
                progress: .progress.N,
                businessName: .businessName.S,
                createdAt: .timestamps.M.createdAt.S
            }'
        else
            echo -e "${YELLOW}⚠️  Job not found${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to query job${NC}"
        echo "$RESULT"
        return 1
    fi
}

# Main script logic
ACTION=${1:-"test-all"}

case "$ACTION" in
    "test-dynamo")
        test_dynamodb
        ;;
    "test-eventbridge")
        test_eventbridge
        ;;
    "test-all")
        echo -e "${BLUE}Testing all connections...${NC}"
        echo ""
        
        DYNAMO_OK=false
        EVENTBRIDGE_OK=false
        
        if test_dynamodb; then
            DYNAMO_OK=true
        fi
        echo ""
        
        if test_eventbridge; then
            EVENTBRIDGE_OK=true
        fi
        echo ""
        
        if $DYNAMO_OK && $EVENTBRIDGE_OK; then
            echo -e "${GREEN}✅ All tests passed! EventBridge system is ready.${NC}"
            echo ""
            echo -e "${BLUE}You can now:${NC}"
            echo -e "   • Send test events: ${YELLOW}$0 send${NC}"
            echo -e "   • Check job status: ${YELLOW}$0 query-job JOB_ID${NC}"
        else
            echo -e "${RED}❌ Some tests failed. Please check your infrastructure deployment.${NC}"
            exit 1
        fi
        ;;
    "send")
        if ! test_dynamodb >/dev/null 2>&1 || ! test_eventbridge >/dev/null 2>&1; then
            echo -e "${RED}❌ Prerequisites not met. Please run: $0 test-all${NC}"
            exit 1
        fi
        send_test_event
        ;;
    "query-job")
        query_job_status "$2"
        ;;
    *)
        echo "Usage: $0 [action]"
        echo ""
        echo "Actions:"
        echo "  test-dynamo       Test DynamoDB connection"
        echo "  test-eventbridge  Test EventBridge connection"
        echo "  test-all          Test all connections (default)"
        echo "  send              Send a test MVP development event"
        echo "  query-job JOB_ID  Query status of a specific job"
        echo ""
        echo "Environment Variables:"
        echo "  AWS_REGION                 AWS region (default: us-east-1)"
        echo "  EVENTBRIDGE_BUS_NAME       EventBridge bus name (default: mvp-development)"
        echo "  DYNAMODB_TABLE_NAME        DynamoDB table name (default: mvp-development-jobs)"
        echo "  FOUNDERDASH_DATABASE_URL   FounderDash database URL"
        ;;
esac
