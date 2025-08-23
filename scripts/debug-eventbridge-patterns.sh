#!/bin/bash

# EventBridge Pattern Debug Script
# Tests different event formats to see which ones match the rule

set -e

REGION="us-east-2"
EVENT_BUS="mvp-development"
RULE_NAME="mvp-pipeline-development-rule"

echo "🔍 EventBridge Pattern Debug Test"
echo "================================="
echo "Testing different event formats to debug pattern matching"
echo ""

# Function to send test event and check metrics
test_event_format() {
    local test_name="$1"
    local event_json="$2"
    
    echo "Test: $test_name"
    echo "Event: $event_json"
    
    # Send event
    RESULT=$(aws events put-events --region "$REGION" --entries "$event_json" 2>&1)
    EVENT_ID=$(echo "$RESULT" | jq -r '.Entries[0].EventId // "unknown"' 2>/dev/null || echo "failed")
    
    echo "Event ID: $EVENT_ID"
    
    # Wait a bit for metrics to update
    sleep 10
    
    # Check metrics for matches in the last 5 minutes
    MATCHES=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Events \
        --metric-name MatchedEvents \
        --dimensions Name=RuleName,Value="$RULE_NAME" Name=EventBusName,Value="$EVENT_BUS" \
        --start-time $(date -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date +%Y-%m-%dT%H:%M:%S) \
        --period 60 \
        --statistics Sum \
        --region "$REGION" \
        --query 'Datapoints[0].Sum // `0`' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$MATCHES" != "0" ] && [ "$MATCHES" != "None" ]; then
        echo "✅ MATCH FOUND! ($MATCHES matches)"
    else
        echo "❌ No matches"
    fi
    echo ""
}

# Test 1: Current format from test script
test_event_format "Current Format" '[{
    "Source": "founderdash.web",
    "DetailType": "MVP Development Request",
    "Detail": "{\"jobId\": \"test_current\", \"userId\": \"test123\"}",
    "EventBusName": "mvp-development"
}]'

# Test 2: Different case variations
test_event_format "Lowercase source" '[{
    "Source": "founderdash.web",
    "DetailType": "mvp development request",
    "Detail": "{\"jobId\": \"test_lower\", \"userId\": \"test123\"}",
    "EventBusName": "mvp-development"
}]'

# Test 3: Exact same format as working old events (if we can find pattern)
test_event_format "Simple minimal" '[{
    "Source": "founderdash.web", 
    "DetailType": "MVP Development Request",
    "Detail": "{\"jobId\": \"test_simple\"}",
    "EventBusName": "mvp-development"
}]'

# Test 4: Different detail structure
test_event_format "Different detail" '[{
    "Source": "founderdash.web",
    "DetailType": "MVP Development Request", 
    "Detail": "{\"businessName\": \"Test\", \"jobId\": \"test_detail\"}",
    "EventBusName": "mvp-development"
}]'

echo "🔍 Rule pattern check:"
aws events describe-rule --name "$RULE_NAME" --event-bus-name "$EVENT_BUS" --region "$REGION" --query 'EventPattern' --output text

echo ""
echo "🔍 Current rule status:"
aws events describe-rule --name "$RULE_NAME" --event-bus-name "$EVENT_BUS" --region "$REGION" --query '{State:State,EventPattern:EventPattern}' --output table

echo ""
echo "Debug complete. Check which format matched above."
