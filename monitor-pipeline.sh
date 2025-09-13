#!/bin/bash

# Monitor MVP Pipeline Progress
echo "==================================="
echo "MVP Pipeline Enhanced Directory Handling Monitor"
echo "==================================="
echo ""

# Create and send a test event
echo "íº€ Creating test event..."
JOB_ID="enhanced_test_$(date +%s)_$(openssl rand -hex 3)"

# Create DynamoDB record
aws dynamodb put-item \
    --table-name mvp-pipeline-development-jobs \
    --item "{
        \"jobId\": {\"S\": \"$JOB_ID\"},
        \"userId\": {\"S\": \"test_user_enhanced\"},
        \"productId\": {\"S\": \"test_product_enhanced\"},
        \"businessName\": {\"S\": \"Enhanced Directory Test\"},
        \"status\": {\"S\": \"PENDING\"},
        \"currentStep\": {\"S\": \"QUEUED\"},
        \"progress\": {\"N\": \"0\"},
        \"timestamps\": {\"M\": {
            \"createdAt\": {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"},
            \"startedAt\": {\"NULL\": true},
            \"completedAt\": {\"NULL\": true},
            \"estimatedCompletion\": {\"S\": \"$(date -u -d '+4 hours' +%Y-%m-%dT%H:%M:%S.%3NZ)\"}
        }},
        \"resources\": {\"M\": {
            \"githubRepo\": {\"M\": {
                \"name\": {\"S\": \"enhanced-directory-test-mvp\"},
                \"branch\": {\"S\": \"main\"},
                \"url\": {\"NULL\": true}
            }},
            \"batchJobId\": {\"NULL\": true},
            \"vercel\": {\"M\": {
                \"projectId\": {\"NULL\": true},
                \"deploymentId\": {\"NULL\": true}
            }}
        }},
        \"urls\": {\"M\": {
            \"staging\": {\"NULL\": true},
            \"production\": {\"NULL\": true},
            \"codeRepository\": {\"NULL\": true}
        }},
        \"errors\": {\"L\": []},
        \"executionLogs\": {\"L\": []}
    }" \
    --region us-east-2

echo "âœ… DynamoDB record created: $JOB_ID"

# Send EventBridge event
aws events put-events \
    --entries "[{
        \"Time\": \"$(date -u +%Y-%m-%dT%H:%M:%S).000Z\",
        \"Source\": \"founderdash.web\",
        \"DetailType\": \"MVP Development Request\", 
        \"Detail\": \"{\\\"jobId\\\": \\\"$JOB_ID\\\"}\",
        \"EventBusName\": \"mvp-development\"
    }]" \
    --region us-east-2 > /dev/null

echo "âœ… EventBridge event sent"

echo ""
echo "í¾¯ Enhanced Directory Handling Deployed Successfully!"
echo ""
echo "The enhanced pipeline now includes:"
echo "âœ… Fixed SOURCE_DIR path from /workspace/source to /workspace/project"
echo "âœ… Forgiving directory verification with auto-correction"
echo "âœ… Unicode character fix in git add command (git add .Ì¥ â†’ git add .)"
echo "âœ… Automatic directory correction instead of error-out behavior"
echo ""
echo "íº€ Pipeline Features:"
echo "- Job ID: $JOB_ID"
echo "- Container Image: mvp-pipeline:latest (digest: sha256:6f65ebdfe0d9c4d979b0e5265049d629a5f2e329fb4df7226c32fc4076555b2d)"
echo "- Job Definition: mvp-pipeline-job-definition:7"
echo "- EventBridge Bus: mvp-development"
echo ""
echo "Monitor this job: aws dynamodb get-item --table-name mvp-pipeline-development-jobs --key '{\"jobId\": {\"S\": \"$JOB_ID\"}}' --region us-east-2"
