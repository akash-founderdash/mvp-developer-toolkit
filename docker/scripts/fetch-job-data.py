#!/usr/bin/env python3
import boto3
import json
import argparse
import os
from datetime import datetime

def fetch_job_data(job_id, output_dir):
    """Fetch complete job data from DynamoDB"""
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
    
    try:
        # Get job record
        response = table.get_item(Key={'jobId': job_id})
        
        if 'Item' not in response:
            raise Exception(f"Job {job_id} not found in DynamoDB")
        
        job_data = response['Item']
        
        # Create MVP specifications markdown
        mvp_specs = f"""# MVP Specifications for {job_data['product']['name']}

## Business Overview
- **Business Name**: {job_data['product']['name']}
- **Tagline**: {job_data['product']['tagline']}
- **Description**: {job_data['product']['description']}
- **Target Audience**: {job_data['specifications']['targetAudience']}

## Key Features
{chr(10).join(['- ' + feature for feature in job_data['specifications']['keyFeatures']])}

## Technical Requirements
{json.dumps(job_data['specifications']['technicalRequirements'], indent=2)}

## Design Preferences  
{json.dumps(job_data['specifications']['designPreferences'], indent=2)}

## Development Guidelines
{job_data['specifications']['mvpSpecs']}
"""

        # Create development instructions
        dev_instructions = job_data['development']['developmentPrompts']
        
        # Write files for Claude Code
        os.makedirs(output_dir, exist_ok=True)
        
        with open(f"{output_dir}/MVP_SPECS.md", "w") as f:
            f.write(mvp_specs)
            
        with open(f"{output_dir}/DEVELOPMENT_INSTRUCTIONS.md", "w") as f:
            f.write(dev_instructions)
        
        # Write complete job data
        with open(f"{output_dir}/job-data.json", "w") as f:
            json.dump(dict(job_data), f, indent=2, default=str)
        
        # Create environment variables for bash script
        with open(f"{output_dir}/job-env.sh", "w") as f:
            f.write(f"""#!/bin/bash
export BUSINESS_NAME="{job_data['product']['name']}"
export REPO_NAME="{job_data['resources']['githubRepo']['name']}"
export PRODUCT_DESCRIPTION="{job_data['product']['description']}"
export USER_EMAIL="{job_data['user']['email']}"
export SANITIZED_NAME="{job_data['product']['sanitizedName']}"
export USER_ID="{job_data['user']['id']}"
export PRODUCT_ID="{job_data['product']['id']}"
""")
        
        print(f"✅ Job data fetched successfully for {job_data['product']['name']}")
        
    except Exception as e:
        print(f"❌ Error fetching job data: {str(e)}")
        raise

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--output-dir", required=True)
    
    args = parser.parse_args()
    fetch_job_data(args.job_id, args.output_dir)