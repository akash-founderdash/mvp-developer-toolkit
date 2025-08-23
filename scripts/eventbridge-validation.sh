#!/bin/bash
# Simple EventBridge validation script

set -e

REGION="us-east-2"
EVENT_BUS_NAME="mvp-development"
RULE_NAME="simple-validation-rule"

echo "=== EventBridge Validation Test ==="

# Step 1: Create a simple rule
echo "Creating simple rule..."
aws events put-rule \
  --name "$RULE_NAME" \
  --event-pattern '{"source":["test.validation"]}' \
  --state ENABLED \
  --region "$REGION" \
  --event-bus-name "$EVENT_BUS_NAME" \
  --description "Simple validation rule"

# Step 2: Add SNS target
SNS_TOPIC_ARN="arn:aws:sns:us-east-2:077075375386:mvp-pipeline-notifications"
echo "Adding SNS target..."
aws events put-targets \
  --rule "$RULE_NAME" \
  --targets Id=1,Arn="$SNS_TOPIC_ARN" \
  --region "$REGION" \
  --event-bus-name "$EVENT_BUS_NAME"

# Step 3: Send test event
echo "Sending test event..."
EVENT_ID=$(aws events put-events \
  --region "$REGION" \
  --entries "[{
    \"Source\": \"test.validation\",
    \"DetailType\": \"Validation Test\",
    \"Detail\": \"{\\\"timestamp\\\": \\\"$(date +%Y-%m-%dT%H:%M:%SZ)\\\", \\\"test\\\": \\\"validation\\\"}\",
    \"EventBusName\": \"$EVENT_BUS_NAME\"
  }]" | jq -r '.Entries[0].EventId')

echo "Event sent with ID: $EVENT_ID"

# Step 4: Wait and check metrics
echo "Waiting 120 seconds for metrics to propagate..."
sleep 120

echo "Checking MatchedEvents metric..."
aws cloudwatch get-metric-statistics \
  --namespace AWS/Events \
  --metric-name MatchedEvents \
  --dimensions Name=RuleName,Value="$RULE_NAME" \
  --start-time "$(date -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S)" \
  --end-time "$(date +%Y-%m-%dT%H:%M:%S)" \
  --period 60 \
  --statistics Sum \
  --region "$REGION"

echo "Checking TriggeredRules metric..."
aws cloudwatch get-metric-statistics \
  --namespace AWS/Events \
  --metric-name TriggeredRules \
  --dimensions Name=RuleName,Value="$RULE_NAME" \
  --start-time "$(date -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S)" \
  --end-time "$(date +%Y-%m-%dT%H:%M:%S)" \
  --period 60 \
  --statistics Sum \
  --region "$REGION"

echo "=== Validation complete ==="
