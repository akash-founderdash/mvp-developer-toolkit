#!/usr/bin/env python3
import boto3
import json
import argparse
import os
from datetime import datetime

def update_job_status(job_id, status=None, step=None, progress=None, repo_url=None, staging_url=None, production_url=None, error=None):
    """Update job status in DynamoDB"""
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
    
    update_expression_parts = []
    expression_attribute_values = {}
    expression_attribute_names = {}
    
    if status:
        update_expression_parts.append("#status = :status")
        expression_attribute_names["#status"] = "status"
        expression_attribute_values[":status"] = status
        
        if status == "IN_PROGRESS":
            update_expression_parts.append("timestamps.startedAt = :started_at")
            expression_attribute_values[":started_at"] = datetime.utcnow().isoformat()
        elif status == "COMPLETED":
            update_expression_parts.append("timestamps.completedAt = :completed_at")
            expression_attribute_values[":completed_at"] = datetime.utcnow().isoformat()
    
    if step:
        update_expression_parts.append("currentStep = :step")
        expression_attribute_values[":step"] = step
    
    if progress is not None:
        update_expression_parts.append("progress = :progress")
        expression_attribute_values[":progress"] = int(progress)
    
    if repo_url:
        update_expression_parts.append("urls.codeRepository = :repo_url")
        expression_attribute_values[":repo_url"] = repo_url
    
    if staging_url:
        update_expression_parts.append("urls.staging = :staging_url")
        expression_attribute_values[":staging_url"] = staging_url
        
    if production_url:
        update_expression_parts.append("urls.production = :production_url")
        expression_attribute_values[":production_url"] = production_url
    
    # Add error information if provided
    if error:
        update_expression_parts.append("errors = list_append(if_not_exists(errors, :empty_list), :error)")
        expression_attribute_values[":empty_list"] = []
        expression_attribute_values[":error"] = [{
            'timestamp': datetime.utcnow().isoformat(),
            'message': error,
            'step': step or 'unknown'
        }]
    
    if update_expression_parts:
        try:
            table.update_item(
                Key={'jobId': job_id},
                UpdateExpression='SET ' + ', '.join(update_expression_parts),
                ExpressionAttributeNames=expression_attribute_names if expression_attribute_names else None,
                ExpressionAttributeValues=expression_attribute_values
            )
            print(f"✅ Updated job {job_id}: {', '.join([f'{k}={v}' for k, v in expression_attribute_values.items()])}")
        except Exception as e:
            print(f"❌ Error updating job status: {str(e)}")
            raise

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--status")
    parser.add_argument("--step") 
    parser.add_argument("--progress", type=int)
    parser.add_argument("--repo-url")
    parser.add_argument("--staging-url")
    parser.add_argument("--production-url")
    parser.add_argument("--error")
    
    args = parser.parse_args()
    update_job_status(
        args.job_id,
        args.status,
        args.step,
        args.progress,
        args.repo_url,
        args.staging_url,
        args.production_url,
        args.error
    )