#!/bin/bash

# EventBridge to AWS Batch Troubleshooting Script
# Helps diagnose why EventBridge events aren't triggering Batch jobs

set -e

REGION=${AWS_REGION:-"us-east-2"}
EVENT_BUS_NAME=${EVENTBRIDGE_BUS_NAME:-"mvp-development"}
RULE_NAME="founderdash-mvp-development-rule"
BATCH_QUEUE="founderdash-mvp-job-queue"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}EventBridge → Batch Troubleshooting${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""

# 1. Check EventBridge rule
echo -e "${BLUE}🔍 Checking EventBridge Rule...${NC}"
RULE_INFO=$(aws events describe-rule --name "$RULE_NAME" --event-bus-name "$EVENT_BUS_NAME" --region "$REGION" 2>/dev/null || echo "")

if [ -n "$RULE_INFO" ]; then
    echo -e "${GREEN}✅ Rule exists and is enabled${NC}"
    echo "$RULE_INFO" | jq .
else
    echo -e "${RED}❌ Rule not found or not accessible${NC}"
    exit 1
fi

echo ""

# 2. Check EventBridge targets
echo -e "${BLUE}🎯 Checking EventBridge Targets...${NC}"
TARGETS=$(aws events list-targets-by-rule --rule "$RULE_NAME" --event-bus-name "$EVENT_BUS_NAME" --region "$REGION" 2>/dev/null || echo "")

if [ -n "$TARGETS" ]; then
    echo -e "${GREEN}✅ Targets configured${NC}"
    echo "$TARGETS" | jq .
    
    # Extract target info
    BATCH_ARN=$(echo "$TARGETS" | jq -r '.Targets[0].Arn // empty')
    ROLE_ARN=$(echo "$TARGETS" | jq -r '.Targets[0].RoleArn // empty')
    
    echo -e "Batch Queue ARN: ${YELLOW}$BATCH_ARN${NC}"
    echo -e "Execution Role: ${YELLOW}$ROLE_ARN${NC}"
else
    echo -e "${RED}❌ No targets found${NC}"
    exit 1
fi

echo ""

# 3. Check Batch queue
echo -e "${BLUE}🗄️ Checking Batch Queue...${NC}"
QUEUE_INFO=$(aws batch describe-job-queues --job-queues "$BATCH_QUEUE" --region "$REGION" 2>/dev/null || echo "")

if [ -n "$QUEUE_INFO" ]; then
    QUEUE_STATE=$(echo "$QUEUE_INFO" | jq -r '.jobQueues[0].state // "unknown"')
    QUEUE_STATUS=$(echo "$QUEUE_INFO" | jq -r '.jobQueues[0].status // "unknown"')
    
    if [ "$QUEUE_STATE" = "ENABLED" ] && [ "$QUEUE_STATUS" = "VALID" ]; then
        echo -e "${GREEN}✅ Batch queue is enabled and valid${NC}"
        echo -e "   State: ${GREEN}$QUEUE_STATE${NC}"
        echo -e "   Status: ${GREEN}$QUEUE_STATUS${NC}"
    else
        echo -e "${YELLOW}⚠️ Batch queue has issues${NC}"
        echo -e "   State: ${YELLOW}$QUEUE_STATE${NC}"
        echo -e "   Status: ${YELLOW}$QUEUE_STATUS${NC}"
    fi
else
    echo -e "${RED}❌ Batch queue not found${NC}"
fi

echo ""

# 4. Test EventBridge to Batch connectivity
echo -e "${BLUE}🧪 Testing EventBridge IAM Permissions...${NC}"

# Get the role ARN from targets
if [ -n "$ROLE_ARN" ]; then
    echo -e "Checking role: ${YELLOW}$(basename $ROLE_ARN)${NC}"
    
    # Check if role exists
    ROLE_INFO=$(aws iam get-role --role-name "$(basename $ROLE_ARN)" --region "$REGION" 2>/dev/null || echo "")
    
    if [ -n "$ROLE_INFO" ]; then
        echo -e "${GREEN}✅ EventBridge execution role exists${NC}"
        
        # Check role policies
        echo -e "${BLUE}📋 Role Policies:${NC}"
        aws iam list-attached-role-policies --role-name "$(basename $ROLE_ARN)" --region "$REGION" --query 'AttachedPolicies[].PolicyName' --output table
        
        echo -e "${BLUE}📋 Inline Policies:${NC}"
        aws iam list-role-policies --role-name "$(basename $ROLE_ARN)" --region "$REGION" --query 'PolicyNames' --output table
    else
        echo -e "${RED}❌ EventBridge execution role not found${NC}"
    fi
else
    echo -e "${RED}❌ No execution role configured${NC}"
fi

echo ""

# 5. Send test event and monitor
echo -e "${BLUE}🚀 Sending test event and monitoring...${NC}"

# Generate test event
TIMESTAMP=$(date +%s)
TEST_JOB_ID="debug_test_${TIMESTAMP}"

# Send event
echo -e "Sending event with Job ID: ${YELLOW}$TEST_JOB_ID${NC}"

EVENT_RESULT=$(aws events put-events --region "$REGION" --entries '[
    {
        "Source": "founderdash.web",
        "DetailType": "MVP Development Request",
        "Detail": "{\"jobId\": \"'$TEST_JOB_ID'\", \"userId\": \"debug_user\", \"productId\": \"debug_product\", \"priority\": \"normal\", \"timestamp\": \"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'\"}",
        "EventBusName": "'$EVENT_BUS_NAME'"
    }
]' 2>&1)

if echo "$EVENT_RESULT" | grep -q "FailedEntryCount.*0"; then
    echo -e "${GREEN}✅ Event sent successfully${NC}"
    EVENT_ID=$(echo "$EVENT_RESULT" | jq -r '.Entries[0].EventId')
    echo -e "Event ID: ${YELLOW}$EVENT_ID${NC}"
    
    # Wait and check for batch job
    echo -e "${BLUE}⏳ Waiting 10 seconds for batch job creation...${NC}"
    sleep 10
    
    # Check for new batch jobs
    echo -e "${BLUE}🔍 Checking for triggered batch jobs...${NC}"
    
    # Check all job statuses
    for STATUS in SUBMITTED RUNNABLE STARTING RUNNING; do
        JOBS=$(aws batch list-jobs --job-queue "$BATCH_QUEUE" --region "$REGION" --job-status "$STATUS" --max-items 5 2>/dev/null || echo '{"jobSummaryList":[]}')
        JOB_COUNT=$(echo "$JOBS" | jq '.jobSummaryList | length')
        
        if [ "$JOB_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✅ Found $JOB_COUNT job(s) with status: $STATUS${NC}"
            echo "$JOBS" | jq '.jobSummaryList[] | {jobName, jobId, status: "'$STATUS'", createdAt}'
        fi
    done
    
    # Check recent jobs (last hour)
    echo -e "${BLUE}🕐 Recent batch jobs (any status, last hour):${NC}"
    RECENT_JOBS=$(aws batch list-jobs --job-queue "$BATCH_QUEUE" --region "$REGION" --max-items 10 2>/dev/null || echo '{"jobSummaryList":[]}')
    RECENT_COUNT=$(echo "$RECENT_JOBS" | jq '.jobSummaryList | length')
    
    if [ "$RECENT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}Found $RECENT_COUNT recent job(s):${NC}"
        echo "$RECENT_JOBS" | jq -r '.jobSummaryList[] | "\(.jobName) | \(.jobId) | \(.jobStatus) | \(.createdAt)"'
    else
        echo -e "${RED}❌ No batch jobs found${NC}"
        echo -e "${YELLOW}💡 This indicates EventBridge is not successfully triggering Batch jobs${NC}"
    fi
    
else
    echo -e "${RED}❌ Failed to send event${NC}"
    echo "$EVENT_RESULT"
fi

echo ""
echo -e "${BLUE}📊 Summary${NC}"
echo -e "${BLUE}=========${NC}"
echo -e "• EventBridge rule: $([ -n "$RULE_INFO" ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}ISSUE${NC}")"
echo -e "• EventBridge targets: $([ -n "$TARGETS" ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}ISSUE${NC}")"
echo -e "• Batch queue: $([ "$QUEUE_STATE" = "ENABLED" ] && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}CHECK${NC}")"
echo -e "• IAM role: $([ -n "$ROLE_INFO" ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}ISSUE${NC}")"

echo ""
echo -e "${BLUE}🔧 Next Steps${NC}"
echo -e "${BLUE}============${NC}"
echo -e "1. Check CloudWatch Logs for EventBridge execution errors"
echo -e "2. Verify EventBridge execution role has batch:SubmitJob permissions"  
echo -e "3. Check if Batch compute environment has capacity"
echo -e "4. Verify job definition and container image accessibility"

echo ""
echo -e "${YELLOW}💡 To check CloudWatch logs:${NC}"
echo -e "aws logs filter-log-events --log-group-name '/aws/events/rule/$RULE_NAME' --region $REGION --start-time \$(date -d '1 hour ago' +%s)000"
