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
        
        # Extract business name from the flat structure
        business_name = job_data.get('businessName', 'Unknown Business')
        user_id = job_data.get('userId', 'unknown')
        product_id = job_data.get('productId', 'unknown')
        
        # Create a sanitized repository name
        sanitized_name = business_name.lower().replace(' ', '-').replace('_', '-')
        repo_name = f"{sanitized_name}-mvp"
        
        # Create MVP specifications markdown using available data
        mvp_specs = f"""# MVP Specifications for {business_name}

## Business Overview
- **Business Name**: {business_name}
- **Description**: Modern web application for {business_name}
- **Repository Name**: {repo_name}

## Key Features (Default MVP Features)
- User authentication and registration
- Dashboard interface
- Basic CRUD operations
- Responsive design
- Modern UI/UX

## Technical Requirements
- Frontend: React/Next.js with TypeScript
- Backend: Node.js with Express
- Database: PostgreSQL or MongoDB
- Styling: Tailwind CSS
- Deployment: Vercel

## Development Guidelines
Create a modern, responsive web application with clean code architecture and user-friendly interface.
"""

        # Create development instructions
        dev_instructions = f"""# Development Instructions for {business_name}

## Overview
Build a modern MVP web application for {business_name} using best practices and modern technologies.

## Key Requirements:
1. Create a clean, professional interface
2. Implement user authentication
3. Build responsive design for mobile and desktop
4. Use TypeScript for type safety
5. Follow React/Next.js best practices
6. Implement proper error handling
7. Add basic testing

## Tech Stack:
- Next.js 14+ with TypeScript
- Tailwind CSS for styling
- Prisma for database management
- NextAuth.js for authentication
- Vercel for deployment

## Deliverables:
1. Complete source code
2. README with setup instructions
3. Deployed application on Vercel
4. Basic documentation
"""
        
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
export BUSINESS_NAME="{business_name}"
export REPO_NAME="{repo_name}"
export PRODUCT_DESCRIPTION="Modern web application for {business_name}"
export USER_EMAIL="user@{sanitized_name}.com"
export SANITIZED_NAME="{sanitized_name}"
export USER_ID="{user_id}"
export PRODUCT_ID="{product_id}"
""")
        
        print(f"✅ Job data fetched successfully for {business_name}")
        
    except Exception as e:
        print(f"❌ Error fetching job data: {str(e)}")
        raise

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--output-dir", required=True)
    
    args = parser.parse_args()
    fetch_job_data(args.job_id, args.output_dir)