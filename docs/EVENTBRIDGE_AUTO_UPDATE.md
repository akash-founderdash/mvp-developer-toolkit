# EventBridge Target Auto-Update System

This system automatically ensures that EventBridge targets always reference the latest AWS Batch Job Definition revision.

## Problem Solved

When AWS Batch Job Definitions are updated (which creates new revisions), EventBridge targets may continue to reference old revisions, causing job submission failures. This system automatically detects and updates EventBridge targets to use the latest revision.

## Components

### 1. Automated Update Script: `scripts/update-eventbridge-target.sh`

**Features:**
- Detects current active job definition revision
- Compares with EventBridge target configuration
- Automatically updates targets if revision mismatch is found
- Verifies updates were applied correctly
- Provides detailed logging and error handling

**Usage:**
```bash
# Manual update
./scripts/update-eventbridge-target.sh

# Or via Makefile
make update-eventbridge
```

### 2. Infrastructure Integration

**Terraform Integration:**
- Added local-exec provisioner to `batch.tf` 
- Automatically runs update script when job definition changes
- Ensures targets stay in sync during infrastructure deployments

**Deployment Integration:**
- Updated `update-infrastructure.sh` to call update script after Terraform apply
- Added `deploy-all` Makefile target for complete deployment + update

### 3. Makefile Commands

```bash
make update-eventbridge    # Update EventBridge targets only
make deploy-all           # Deploy infrastructure + update EventBridge
make eb-targets          # View current EventBridge targets
make eb-rules            # View EventBridge rules
```

## How It Works

### Detection Process
1. Query AWS Batch for active job definition revision
2. Query EventBridge for current target job definition
3. Compare revisions to detect mismatches

### Update Process
1. Generate new target configuration with latest revision
2. Update EventBridge target using AWS CLI
3. Verify the update was successful
4. Log results and any errors

### Integration Points
- **Terraform Apply**: Automatically triggered via local-exec provisioner
- **Manual Updates**: Available via script or Makefile
- **CI/CD Integration**: Can be added to deployment pipelines

## Configuration

Environment variables can override defaults:

```bash
export AWS_DEFAULT_REGION="us-east-2"
export EVENTBRIDGE_BUS_NAME="mvp-development" 
export RULE_NAME="mvp-pipeline-development-rule"
export JOB_DEFINITION_NAME="mvp-pipeline-job-definition"
export JOB_QUEUE_ARN="arn:aws:batch:us-east-2:077075375386:job-queue/mvp-pipeline-job-queue"
export EVENTBRIDGE_ROLE_ARN="arn:aws:iam::077075375386:role/mvp-pipeline-eventbridge-role"
```

## Testing

### Test EventBridge System
```bash
# Test complete system
./scripts/eventbridge-test-cli.sh test-all

# Send test event
./scripts/eventbridge-test-cli.sh send

# Check if targets are up to date
./scripts/update-eventbridge-target.sh
```

### Verify Job Definition Revision
```bash
# Check current active revision
aws batch describe-job-definitions \
  --job-definition-name mvp-pipeline-job-definition \
  --status ACTIVE \
  --region us-east-2 \
  --query 'jobDefinitions[0].revision'

# Check EventBridge target revision  
aws events list-targets-by-rule \
  --rule mvp-pipeline-development-rule \
  --event-bus-name mvp-development \
  --region us-east-2 \
  --query 'Targets[0].BatchParameters.JobDefinition'
```

## Troubleshooting

### Common Issues

1. **Permission Errors**
   - Ensure EventBridge role has `batch:SubmitJob` permissions
   - Verify IAM roles are properly configured

2. **Target Update Failures**
   - Check AWS CLI credentials and permissions
   - Verify EventBridge rule and target exist
   - Review IAM policies for EventBridge service

3. **EventBridge Not Triggering Jobs**
   - Verify event pattern matches
   - Check job definition exists and is ACTIVE
   - Review CloudWatch logs for EventBridge rule executions

### Debug Commands
```bash
# Check EventBridge rule status
aws events describe-rule --name mvp-pipeline-development-rule --event-bus-name mvp-development --region us-east-2

# List all targets for rule
aws events list-targets-by-rule --rule mvp-pipeline-development-rule --event-bus-name mvp-development --region us-east-2

# Test event pattern matching
aws events test-event-pattern --event-pattern '{"source":["founderdash.web"],"detail-type":["MVP Development Request"]}' --event '{"Source":"founderdash.web","DetailType":"MVP Development Request","Detail":"{}"}'
```

## Best Practices

1. **Always use `deploy-all` for infrastructure changes** to ensure EventBridge targets are updated
2. **Run `update-eventbridge` after manual job definition changes**
3. **Monitor EventBridge and Batch logs** to verify successful job submissions
4. **Test with `eventbridge-test-cli.sh send`** after any changes
5. **Use versioned job definitions** to maintain deployment history

## Future Enhancements

- CloudWatch alarm for EventBridge target mismatches
- Automated notification when updates are applied
- Integration with AWS Systems Manager for scheduled checks
- Support for multiple EventBridge rules and targets
- Rollback capability for failed updates
