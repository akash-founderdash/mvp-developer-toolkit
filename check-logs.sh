#!/bin/bash

# Work around Windows path issue
JOB_ID="7bc3d438-5f4f-418d-a14b-43dbb0b827ea"
LOG_GROUP="/aws/batch/mvp-pipeline"
LOG_STREAM="mvp-pipeline/default/316e2aa2b510497e9794d244e6956085"

echo "Checking logs for job: $JOB_ID"
echo "Log group: $LOG_GROUP"
echo "Log stream: $LOG_STREAM"
echo ""

# Get the logs
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --region us-east-2 \
  --start-from-head \
  --query 'events[].message' \
  --output text

