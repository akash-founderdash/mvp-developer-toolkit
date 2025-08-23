#!/bin/bash

echo "🔍 EventBridge Debug Test"
echo "========================="

REGION="us-east-2"
EVENT_BUS="mvp-development"
JOB_ID="debug_test_$(date +%s)"

echo "Job ID: $JOB_ID"
echo "Region: $REGION"
echo "Event Bus: $EVENT_BUS"
echo ""

# Step 1: Check if EventBridge bus exists
echo "Step 1: Checking EventBridge bus..."
if aws events describe-event-bus --name $EVENT_BUS --region $REGION >/dev/null 2>&1; then
    echo "✅ EventBridge bus exists"
    BUS_ARN=$(aws events describe-event-bus --name $EVENT_BUS --region $REGION --query 'Arn' --output text)
    echo "   ARN: $BUS_ARN"
else
    echo "❌ EventBridge bus does not exist"
    echo "Available event buses:"
    aws events list-event-buses --region $REGION --query 'EventBuses[].Name' --output table
    exit 1
fi

# Step 2: Check if rule exists
echo ""
echo "Step 2: Checking EventBridge rule..."
RULE_NAME="founderdash-mvp-development-rule"
if aws events describe-rule --name $RULE_NAME --event-bus-name $EVENT_BUS --region $REGION >/dev/null 2>&1; then
    echo "✅ EventBridge rule exists: $RULE_NAME"
    
    # Check if rule is enabled
    RULE_STATE=$(aws events describe-rule --name $RULE_NAME --event-bus-name $EVENT_BUS --region $REGION --query 'State' --output text)
    echo "   Rule state: $RULE_STATE"
    
    # Check rule pattern
    echo "   Rule pattern:"
    aws events describe-rule --name $RULE_NAME --event-bus-name $EVENT_BUS --region $REGION --query 'EventPattern' --output text
    
    # Check rule targets
    echo "   Rule targets:"
    aws events list-targets-by-rule --rule $RULE_NAME --event-bus-name $EVENT_BUS --region $REGION --query 'Targets[].{Id:Id,Arn:Arn}' --output table
else
    echo "❌ EventBridge rule '$RULE_NAME' does not exist"
    echo "Available rules in bus '$EVENT_BUS':"
    aws events list-rules --event-bus-name $EVENT_BUS --region $REGION --query 'Rules[].{Name:Name,State:State}' --output table
    
    echo ""
    echo "Available rules in all buses:"
    aws events list-rules --region $REGION --query 'Rules[].{Name:Name,EventBusName:EventBusName,State:State}' --output table
    exit 1
fi

# Step 3: Check if Batch queue exists
echo ""
echo "Step 3: Checking Batch job queue..."
if aws batch describe-job-queues --job-queues founderdash-mvp-job-queue --region $REGION >/dev/null 2>&1; then
    echo "✅ Batch job queue exists"
    
    # Check queue state
    QUEUE_STATE=$(aws batch describe-job-queues --job-queues founderdash-mvp-job-queue --region $REGION --query 'jobQueues[0].state' --output text)
    QUEUE_STATUS=$(aws batch describe-job-queues --job-queues founderdash-mvp-job-queue --region $REGION --query 'jobQueues[0].status' --output text)
    echo "   Queue state: $QUEUE_STATE"
    echo "   Queue status: $QUEUE_STATUS"
else
    echo "❌ Batch job queue 'founderdash-mvp-job-queue' does not exist"
    echo "Available queues:"
    aws batch describe-job-queues --region $REGION --query 'jobQueues[].{Name:jobQueueName,State:state,Status:status}' --output table
    exit 1
fi

# Step 4: Check job definition
echo ""
echo "Step 4: Checking Batch job definition..."
if aws batch describe-job-definitions --job-definition-name founderdash-mvp-job --region $REGION >/dev/null 2>&1; then
    echo "✅ Batch job definition exists"
    
    JOB_DEF_STATUS=$(aws batch describe-job-definitions --job-definition-name founderdash-mvp-job --region $REGION --query 'jobDefinitions[0].status' --output text)
    echo "   Job definition status: $JOB_DEF_STATUS"
    
    # Check container image
    CONTAINER_IMAGE=$(aws batch describe-job-definitions --job-definition-name founderdash-mvp-job --region $REGION --query 'jobDefinitions[0].containerProperties.image' --output text)
    echo "   Container image: $CONTAINER_IMAGE"
else
    echo "❌ Batch job definition 'founderdash-mvp-job' does not exist"
    echo "Available job definitions:"
    aws batch describe-job-definitions --region $REGION --query 'jobDefinitions[].jobDefinitionName' --output table
    exit 1
fi

# Step 5: Check DynamoDB table
echo ""
echo "Step 5: Checking DynamoDB table..."
if aws dynamodb describe-table --table-name founderdash-mvp-development-jobs --region $REGION >/dev/null 2>&1; then
    echo "✅ DynamoDB table exists"
    
    TABLE_STATUS=$(aws dynamodb describe-table --table-name founderdash-mvp-development-jobs --region $REGION --query 'Table.TableStatus' --output text)
    echo "   Table status: $TABLE_STATUS"
else
    echo "❌ DynamoDB table 'founderdash-mvp-development-jobs' does not exist"
    echo "Available tables:"
    aws dynamodb list-tables --region $REGION --query 'TableNames' --output table
    exit 1
fi

# Step 6: Create DynamoDB record first
echo ""
echo "Step 6: Creating DynamoDB job record..."
CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

if aws dynamodb put-item --table-name founderdash-mvp-development-jobs --region $REGION --item '{
    "jobId": {"S": "'$JOB_ID'"},
    "userId": {"S": "debug_user_123"},
    "status": {"S": "PENDING"},
    "businessName": {"S": "Debug Test Business"},
    "createdAt": {"S": "'$CURRENT_TIME'"},
    "updatedAt": {"S": "'$CURRENT_TIME'"},
    "timestamps": {
        "M": {
            "createdAt": {"S": "'$CURRENT_TIME'"}
        }
    }
}' >/dev/null 2>&1; then
    echo "✅ DynamoDB record created"
else
    echo "❌ Failed to create DynamoDB record"
    exit 1
fi

# Step 7: Send EventBridge event
echo ""
echo "Step 7: Sending EventBridge event..."
RESULT=$(aws events put-events --region $REGION --entries '[
    {
        "Source": "founderdash.web",
        "DetailType": "MVP Development Request",
        "Detail": "{\"jobId\": \"'$JOB_ID'\", \"userId\": \"debug_user_123\", \"businessName\": \"Debug Test Business\", \"priority\": \"normal\", \"timestamp\": \"'$CURRENT_TIME'\"}",
        "EventBusName": "'$EVENT_BUS'"
    }
]' 2>&1)

echo "EventBridge response:"
echo "$RESULT"

if echo "$RESULT" | grep -q "EventId"; then
    EVENT_ID=$(echo "$RESULT" | jq -r '.Entries[0].EventId' 2>/dev/null || echo "unknown")
    FAILED_COUNT=$(echo "$RESULT" | jq -r '.FailedEntryCount' 2>/dev/null || echo "unknown")
    
    echo ""
    echo "✅ Event sent successfully!"
    echo "Event ID: $EVENT_ID"
    echo "Failed Count: $FAILED_COUNT"
else
    echo ""
    echo "❌ Failed to send EventBridge event"
    exit 1
fi

# Step 8: Wait and check for Batch job
echo ""
echo "Step 8: Waiting 30 seconds for Batch job to be triggered..."
sleep 30

echo "Checking for new Batch jobs..."

# Check all recent jobs
echo "All jobs in queue:"
aws batch list-jobs --job-queue founderdash-mvp-job-queue --region $REGION --query 'jobList[0:5].{JobId:jobId,JobName:jobName,Status:jobStatus,CreatedAt:createdAt}' --output table 2>/dev/null || echo "No jobs found"

# Check jobs by status
for status in SUBMITTED PENDING RUNNABLE STARTING RUNNING; do
    echo ""
    echo "Jobs with status $status:"
    aws batch list-jobs --job-queue founderdash-mvp-job-queue --job-status $status --region $REGION --query 'jobList[0:3].{JobId:jobId,JobName:jobName,CreatedAt:createdAt}' --output table 2>/dev/null || echo "No $status jobs"
done

# Step 9: Check EventBridge metrics
echo ""
echo "Step 9: Checking EventBridge metrics..."

CURRENT_EPOCH=$(date +%s)
ONE_HOUR_AGO=$((CURRENT_EPOCH - 3600))

echo "Rule invocations in last hour:"
aws cloudwatch get-metric-statistics \
    --namespace "AWS/Events" \
    --metric-name "InvocationsCount" \
    --dimensions Name=RuleName,Value=founderdash-mvp-development-rule \
    --start-time "$(date -u -d @$ONE_HOUR_AGO +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u -d @$CURRENT_EPOCH +%Y-%m-%dT%H:%M:%S)" \
    --period 3600 \
    --statistic Sum \
    --region $REGION \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "No metrics available"

echo ""
echo "Rule failed invocations in last hour:"
aws cloudwatch get-metric-statistics \
    --namespace "AWS/Events" \
    --metric-name "FailedInvocations" \
    --dimensions Name=RuleName,Value=founderdash-mvp-development-rule \
    --start-time "$(date -u -d @$ONE_HOUR_AGO +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u -d @$CURRENT_EPOCH +%Y-%m-%dT%H:%M:%S)" \
    --period 3600 \
    --statistic Sum \
    --region $REGION \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "No failure metrics"

echo ""
echo "🎯 Debug test complete!"
echo ""
echo "Summary:"
echo "- EventBridge Bus: ✅"
echo "- EventBridge Rule: ✅" 
echo "- Batch Queue: ✅"
echo "- Job Definition: ✅"
echo "- DynamoDB Table: ✅"
echo "- Event Sent: ✅"
echo "- Event ID: $EVENT_ID"
echo ""
echo "Next steps:"
echo "1. Check if Batch jobs were created above"
echo "2. If no Batch jobs, the issue is EventBridge → Batch integration"
echo "3. Check container image exists in ECR"
echo "4. Verify EventBridge IAM permissions"
