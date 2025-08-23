# EventBridge Deployment Guide

## Prerequisites

1. **AWS CLI installed and configured**
2. **Terraform installed** (version 1.0+)
3. **AWS credentials configured** with appropriate permissions

## Step 1: Configure Variables

First, set up your Terraform variables. Create or update `infrastructure/terraform.tfvars`:

```hcl
# infrastructure/terraform.tfvars
project_name = "founderdash-mvp"
aws_region = "us-east-1"

# VPC Configuration (if you have an existing VPC)
vpc_id = "vpc-xxxxxxxx"  # Optional: your existing VPC ID
subnet_ids = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]  # Optional: your existing subnet IDs

# GitHub Configuration  
github_token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
github_username = "founderdash-bot"  # or your GitHub username

# Vercel Configuration
vercel_token = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
vercel_team_id = "team_xxxxxxxxxxxxxxxxxxxxxxxx"  # Optional

# Database: Using DynamoDB for job tracking (configured automatically by Terraform)
# founderdash_database_url variable has been removed - not needed with DynamoDB
```

## Step 2: Initialize Terraform

```bash
cd infrastructure
terraform init
```

## Step 3: Plan the Deployment

Review what will be created:

```bash
terraform plan
```

You should see resources being created including:
- EventBridge custom bus (`aws_cloudwatch_event_bus.mvp_development`)
- EventBridge rules for MVP development events
- EventBridge targets pointing to AWS Batch
- IAM roles and policies
- DynamoDB table for job tracking
- AWS Batch job definition and queue
- SNS topics for notifications
- SQS dead letter queue

## Step 4: Deploy the Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

## Step 5: Verify EventBridge Creation

After deployment, verify the EventBridge resources:

```bash
# Check if the custom event bus exists
aws events describe-event-bus --name mvp-development

# List EventBridge rules
aws events list-rules --event-bus-name mvp-development

# Check rule details
aws events describe-rule --name founderdash-mvp-development-rule --event-bus-name mvp-development
```

## Step 6: Test EventBridge

Use the provided test script:

```bash
# Set environment variables
export AWS_REGION=us-east-1
export DYNAMODB_TABLE_NAME=mvp-development-jobs
export EVENTBRIDGE_BUS_NAME=mvp-development

# Test the connection
node tooling/scripts/simple-eventbridge-test.js test-all

# Send a test event
node tooling/scripts/simple-eventbridge-test.js send
```

## Alternative: Manual EventBridge Creation (AWS CLI)

If you prefer to create EventBridge resources manually without Terraform:

### 1. Create Custom Event Bus

```bash
aws events create-event-bus --name mvp-development
```

### 2. Create EventBridge Rule

```bash
aws events put-rule \\
  --name mvp-development-rule \\
  --event-bus-name mvp-development \\
  --event-pattern '{
    "source": ["founderdash.web"],
    "detail-type": ["MVP Development Request"]
  }' \\
  --description "Rule to trigger MVP development pipeline"
```

### 3. Create IAM Role for EventBridge

```bash
# Create trust policy file
cat > eventbridge-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \\
  --role-name EventBridgeBatchRole \\
  --assume-role-policy-document file://eventbridge-trust-policy.json

# Attach policy for Batch permissions
cat > eventbridge-batch-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "batch:SubmitJob",
        "batch:DescribeJobs",
        "batch:DescribeJobQueues",
        "batch:DescribeJobDefinitions"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \\
  --role-name EventBridgeBatchRole \\
  --policy-name BatchSubmitPolicy \\
  --policy-document file://eventbridge-batch-policy.json
```

### 4. Add Target to EventBridge Rule

```bash
# You'll need your Batch job queue ARN and job definition name
aws events put-targets \\
  --rule mvp-development-rule \\
  --event-bus-name mvp-development \\
  --targets '[
    {
      "Id": "1",
      "Arn": "arn:aws:batch:us-east-1:123456789012:job-queue/mvp-pipeline-queue",
      "RoleArn": "arn:aws:iam::123456789012:role/EventBridgeBatchRole",
      "BatchParameters": {
        "JobDefinition": "mvp-pipeline-job",
        "JobName": "mvp-development-job"
      },
      "InputTransformer": {
        "InputPathsMap": {
          "jobId": "$.detail.jobId"
        },
        "InputTemplate": "{\\"Parameters\\": {\\"JOB_ID\\": \\"<jobId>\\"}}"
      }
    }
  ]'
```

## Troubleshooting

### 1. EventBridge Bus Not Found

```bash
# Check if the bus exists
aws events list-event-buses

# If not found, create it
aws events create-event-bus --name mvp-development
```

### 2. Permission Denied

Ensure your AWS credentials have the following permissions:
- `events:*`
- `batch:*`
- `iam:*`
- `dynamodb:*`
- `sns:*`
- `sqs:*`

### 3. Terraform State Issues

```bash
# If you need to reset Terraform state
terraform destroy  # Warning: This deletes all resources!
rm -rf .terraform
rm terraform.tfstate*
terraform init
terraform plan
terraform apply
```

### 4. Test Event Not Triggering Batch Job

1. Check EventBridge rule exists and is enabled:
```bash
aws events describe-rule --name mvp-development-rule --event-bus-name mvp-development
```

2. Verify Batch resources exist:
```bash
aws batch describe-job-queues
aws batch describe-job-definitions
```

3. Check CloudWatch logs for EventBridge rule execution:
```bash
aws logs filter-log-events --log-group-name /aws/events/rule/mvp-development-rule
```

## Environment Variables Reference

After deployment, set these environment variables in your application:

```bash
# Required for EventBridge client
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export EVENTBRIDGE_BUS_NAME=mvp-development
export DYNAMODB_TABLE_NAME=mvp-development-jobs
# Database: Using DynamoDB (no PostgreSQL URL needed)
# export FOUNDERDASH_DATABASE_URL=postgresql://user:pass@host:5432/founderdash

# Optional
export SNS_COMPLETION_TOPIC_ARN=arn:aws:sns:us-east-1:123456789012:mvp-completion
```

## Next Steps

1. **Deploy Infrastructure**: Use Terraform to create all AWS resources
2. **Test EventBridge**: Use the provided test scripts
3. **Integrate with Your App**: Use the API endpoints to send events
4. **Monitor**: Set up CloudWatch dashboards for monitoring
5. **Scale**: Configure auto-scaling for Batch compute environments

The EventBridge system is now ready to receive MVP development requests and trigger your AWS Batch jobs! 🚀
