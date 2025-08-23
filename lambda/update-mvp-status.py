import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
jobs_table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
status_table = dynamodb.Table(os.environ['STATUS_TABLE'])

def decimal_default(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

def lambda_handler(event, context):
    """
    Process SNS messages from MVP development completion
    """
    try:
        # Parse SNS message
        for record in event['Records']:
            if record['EventSource'] == 'aws:sns':
                message = json.loads(record['Sns']['Message'])
                
                job_id = message.get('jobId')
                status = message.get('status', 'completed')
                
                if not job_id:
                    print(f"No jobId found in message: {message}")
                    continue
                
                # Update main jobs table
                update_job_record(job_id, message)
                
                # Update status table for quick queries
                update_status_record(message)
                
                print(f"Successfully updated status for job {job_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Status updated successfully')
        }
        
    except Exception as e:
        print(f"Error processing status update: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def update_job_record(job_id, message):
    """Update the main job record in DynamoDB"""
    
    update_expression_parts = []
    expression_attribute_values = {}
    expression_attribute_names = {}
    
    # Always update status and completion time
    status = message.get('status', 'completed')
    update_expression_parts.append("#status = :status")
    update_expression_parts.append("timestamps.completedAt = :completed_at")
    expression_attribute_names["#status"] = "status"
    expression_attribute_values[":status"] = status
    expression_attribute_values[":completed_at"] = datetime.utcnow().isoformat()
    
    # Update progress to 100% if completed
    if status == 'completed':
        update_expression_parts.append("progress = :progress")
        update_expression_parts.append("currentStep = :step")
        expression_attribute_values[":progress"] = 100
        expression_attribute_values[":step"] = "COMPLETED"
    
    # Update URLs if provided
    if message.get('repoUrl'):
        update_expression_parts.append("urls.codeRepository = :repo_url")
        expression_attribute_values[":repo_url"] = message['repoUrl']
    
    if message.get('productionUrl'):
        update_expression_parts.append("urls.production = :production_url")
        expression_attribute_values[":production_url"] = message['productionUrl']
    
    if message.get('stagingUrl'):
        update_expression_parts.append("urls.staging = :staging_url")
        expression_attribute_values[":staging_url"] = message['stagingUrl']
    
    # Update resource information
    if message.get('batchJobId'):
        update_expression_parts.append("resources.batchJobId = :batch_job_id")
        expression_attribute_values[":batch_job_id"] = message['batchJobId']
    
    if message.get('vercelProjectId'):
        update_expression_parts.append("resources.vercel.projectId = :vercel_project_id")
        expression_attribute_values[":vercel_project_id"] = message['vercelProjectId']
    
    if message.get('vercelDeploymentId'):
        update_expression_parts.append("resources.vercel.deploymentId = :vercel_deployment_id")
        expression_attribute_values[":vercel_deployment_id"] = message['vercelDeploymentId']
    
    # Add error information if status is failed
    if status == 'failed' and message.get('error'):
        update_expression_parts.append("errors = list_append(if_not_exists(errors, :empty_list), :error)")
        expression_attribute_values[":empty_list"] = []
        expression_attribute_values[":error"] = [{
            'timestamp': datetime.utcnow().isoformat(),
            'message': message['error'],
            'step': message.get('currentStep', 'unknown')
        }]
    
    # Execute update
    if update_expression_parts:
        jobs_table.update_item(
            Key={'jobId': job_id},
            UpdateExpression='SET ' + ', '.join(update_expression_parts),
            ExpressionAttributeNames=expression_attribute_names,
            ExpressionAttributeValues=expression_attribute_values
        )

def update_status_record(message):
    """Update the status table for quick queries"""
    
    job_id = message.get('jobId')
    project_id = message.get('projectId', job_id)  # Use jobId as fallback
    user_id = message.get('userId')
    
    if not all([job_id, project_id]):
        print(f"Missing required fields for status update: jobId={job_id}, projectId={project_id}")
        return
    
    status_record = {
        'projectId': project_id,
        'jobId': job_id,
        'status': message.get('status', 'completed'),
        'updatedAt': datetime.utcnow().isoformat(),
        'urls': {
            'production': message.get('productionUrl'),
            'staging': message.get('stagingUrl'),
            'repository': message.get('repoUrl')
        }
    }
    
    # Add user ID if available
    if user_id:
        status_record['userId'] = user_id
    
    # Add business name if available
    if message.get('businessName'):
        status_record['businessName'] = message['businessName']
    
    # Add TTL for automatic cleanup (30 days)
    ttl_timestamp = int(datetime.utcnow().timestamp()) + (30 * 24 * 60 * 60)
    status_record['ttl'] = ttl_timestamp
    
    # Put item in status table
    status_table.put_item(Item=status_record)