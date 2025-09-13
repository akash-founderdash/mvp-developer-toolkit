# EventBridge MVP Development System

This system provides a complete solution for sending MVP development requests to AWS EventBridge, which then triggers AWS Batch jobs for automated MVP development.

## Architecture Overview

```
FounderDash Web App → EventBridge → AWS Batch → MVP Development Container
                            ↓
                    DynamoDB (Job Tracking)
```

## Quick Start

### 1. Setup Environment

Copy the example environment file and configure your AWS credentials:

```bash
cp .env.eventbridge.example .env.eventbridge
```

Edit `.env.eventbridge` with your actual AWS credentials and configuration:

```bash
# Required AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...

# EventBridge Settings (from infrastructure/eventbridge.tf)
EVENTBRIDGE_BUS_NAME=mvp-development
DYNAMODB_TABLE_NAME=mvp-development-jobs
# Database: Using DynamoDB for job tracking (no PostgreSQL URL needed)
```

### 2. Install Dependencies

```bash
cd packages/api
pnpm install
```

### 3. Test EventBridge Connection

```bash
# Test basic connection
node ../../tooling/scripts/eventbridge-test-cli.js --action test

# Send a test MVP development request
node ../../tooling/scripts/eventbridge-test-cli.js \\
  --action send \\
  --user-id "user123" \\
  --product-id "prod456" \\
  --business-name "My Startup MVP"
```

## Components

### 1. EventBridge Client (`packages/api/src/eventbridge-client.ts`)

TypeScript client for sending events to EventBridge:

```typescript
import { createMVPEventBridgeClient } from './packages/api/src/eventbridge-client';

const client = createMVPEventBridgeClient();

await client.sendMVPDevelopmentRequest({
  jobId: 'job_123',
  userId: 'user123',
  productId: 'prod456',
  founderdashDbUrl: 'postgresql://...',
  priority: 'high',
  metadata: {
    businessName: 'My Startup',
    features: ['auth', 'dashboard', 'payments']
  }
});
```

### 2. API Endpoints (`packages/api/src/mvp-deployment-api.ts`)

Hono-based REST API for MVP deployment:

- **POST** `/deploy` - Deploy a new MVP
- **GET** `/status/:jobId` - Get job status
- **GET** `/jobs/:userId` - List user's jobs
- **DELETE** `/jobs/:jobId` - Cancel a job
- **POST** `/test-connection` - Test EventBridge connection

### 3. Test CLI (`tooling/scripts/eventbridge-test-cli.js`)

Command-line interface for testing:

```bash
# Send single event
node eventbridge-test-cli.js --action send --user-id user123 --product-id prod456

# Send batch events
node eventbridge-test-cli.js --action batch

# Test connection
node eventbridge-test-cli.js --action test
```

## Usage Examples

### Integration with FounderDash Web App

```typescript
// In your FounderDash backend
import { createMVPEventBridgeClient } from '@repo/api';

const eventBridgeClient = createMVPEventBridgeClient();

// When user clicks "Deploy MVP"
app.post('/api/mvp/deploy', async (req, res) => {
  const { userId, productId } = req.body;
  
  // Create job record in DynamoDB
  const jobId = await createJobRecord(userId, productId);
  
  // Send event to EventBridge
  const eventId = await eventBridgeClient.sendMVPDevelopmentRequest({
    jobId,
    userId,
    productId,
    founderdashDbUrl: process.env.DATABASE_URL,
    priority: 'normal'
  });
  
  res.json({ jobId, eventId, status: 'queued' });
});
```

### Batch Processing

```typescript
// Send multiple MVP requests at once
const events = [
  { jobId: 'job1', userId: 'user1', productId: 'prod1', founderdashDbUrl: '...' },
  { jobId: 'job2', userId: 'user2', productId: 'prod2', founderdashDbUrl: '...' },
  // ... up to 10 events per batch
];

const eventIds = await client.sendBatchMVPRequests(events);
```

### Custom Events

```typescript
// Send custom events to EventBridge
await client.sendCustomEvent(
  'founderdash.admin', 
  'MVP Batch Complete',
  { 
    batchId: 'batch123', 
    completedCount: 5,
    failedCount: 1 
  }
);
```

## Event Structure

EventBridge events sent to the `mvp-development` bus have this structure:

```json
{
  "Source": "founderdash.web",
  "DetailType": "MVP Development Request",
  "Detail": {
    "jobId": "job_1734567890123_abc123def",
    "userId": "user123",
    "productId": "prod456", 
    "founderdashDbUrl": "postgresql://...",
    "priority": "normal",
    "timestamp": "2025-08-20T10:30:00.000Z",
    "metadata": {
      "businessName": "My Startup",
      "estimatedDuration": 14400,
      "features": ["auth", "dashboard"],
      "userEmail": "user@example.com"
    }
  },
  "EventBusName": "mvp-development"
}
```

## EventBridge Rules & Targets

The infrastructure (`infrastructure/eventbridge.tf`) creates:

1. **EventBridge Rule**: Matches events with:
   - Source: `founderdash.web`
   - DetailType: `MVP Development Request`

2. **Batch Target**: Triggers AWS Batch job with:
   - Job Definition: `mvp-pipeline-job`
   - Job Queue: `mvp-pipeline-queue`
   - Environment: `JOB_ID` from event

3. **Dead Letter Queue**: Captures failed events for debugging

## Monitoring & Debugging

### 1. CloudWatch Logs

Monitor EventBridge execution:

```bash
aws logs tail /aws/events/rule/mvp-development-rule --follow
```

### 2. DynamoDB Job Status

Query job status:

```bash
aws dynamodb get-item \\
  --table-name mvp-development-jobs \\
  --key '{"jobId": {"S": "job_123"}}'
```

### 3. AWS Batch Job Status

Check batch job execution:

```bash
aws batch describe-jobs --jobs job-123
```

## Error Handling

The system includes comprehensive error handling:

1. **EventBridge Failures**: Captured in DLQ for retry
2. **Batch Job Failures**: Status updated in DynamoDB
3. **API Errors**: Proper HTTP status codes and error messages
4. **Connection Issues**: Automatic retry with exponential backoff

## Security Considerations

1. **IAM Roles**: EventBridge requires permissions for:
   - `events:PutEvents`
   - `batch:SubmitJob`
   - `dynamodb:PutItem`, `dynamodb:GetItem`

2. **Environment Variables**: Store sensitive data securely:
   - Use AWS Secrets Manager for production
   - Never commit `.env` files with real credentials

3. **VPC Configuration**: Batch jobs run in private subnets

## Deployment

### 1. Infrastructure

Deploy the EventBridge infrastructure:

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

### 2. Environment Setup

Set up your environment variables:

```bash
# Load environment
source .env.eventbridge

# Verify EventBridge bus exists
aws events describe-event-bus --name $EVENTBRIDGE_BUS_NAME
```

### 3. Test End-to-End

```bash
# Send test event and verify batch job creation
node tooling/scripts/eventbridge-test-cli.js \\
  --action send \\
  --user-id test-user \\
  --product-id test-product

# Check if batch job was created
aws batch list-jobs --job-queue mvp-pipeline-job-queue
```

## Troubleshooting

### Common Issues

1. **"Event bus not found"**
   - Verify EventBridge bus exists: `aws events list-event-buses`
   - Deploy infrastructure: `terraform apply`

2. **"Access denied"**
   - Check IAM permissions for EventBridge and Batch
   - Verify AWS credentials: `aws sts get-caller-identity`

3. **"Batch job not triggered"**
   - Check EventBridge rule is enabled
   - Verify event pattern matches your event structure
   - Check CloudWatch logs for rule execution

4. **"DynamoDB access denied"**
   - Verify table exists: `aws dynamodb describe-table --table-name mvp-development-jobs`
   - Check IAM permissions for DynamoDB operations

### Debug Commands

```bash
# Test EventBridge connection
node eventbridge-test-cli.js --action test

# Send test event with debug logging
DEBUG=1 node eventbridge-test-cli.js --action send --user-id debug --product-id debug

# Check recent EventBridge events
aws logs filter-log-events --log-group-name /aws/events/rule/mvp-development-rule --start-time $(date -d '1 hour ago' +%s)000
```

## Next Steps

1. **Production Integration**: Replace placeholder database functions with real PostgreSQL queries
2. **Authentication**: Add API authentication for production use
3. **Monitoring**: Set up CloudWatch alarms for failed events
4. **Scaling**: Configure auto-scaling for Batch compute environments
5. **Cost Optimization**: Implement spot instances for non-critical workloads

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS CloudWatch logs
3. Verify infrastructure deployment
4. Test with CLI tools before integrating
