# MVP EventBridge Development System

A complete AWS EventBridge-powered system for automated MVP development using containerized workflows.

## 🏗️ System Overview

This system provides an automated pipeline that:
1. **Receives MVP development requests** via AWS EventBridge events
2. **Triggers containerized development workflows** using AWS Batch
3. **Stores job status and metadata** in DynamoDB
4. **Sends completion notifications** via SNS
5. **Manages the entire MVP lifecycle** from request to deployment

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Docker Desktop installed and running
- Terraform >= 1.0
- Node.js >= 18 (for testing)

### 1. Deploy Infrastructure

```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
terraform init
terraform plan
terraform apply
```

### 2. Build and Deploy Container

```bash
cd docker
# Login to ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com

# Build and push container
docker build -t mvp-pipeline:latest .
docker tag mvp-pipeline:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com/founderdash/mvp-pipeline:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-2.amazonaws.com/founderdash/mvp-pipeline:latest
```

### 3. Test the System

```bash
cd scripts
chmod +x test-event-debug.sh
./test-event-debug.sh
```

## 📁 Project Structure

```
mvp-eventbridge-system/
├── infrastructure/          # Terraform infrastructure code
│   ├── main.tf             # Main configuration
│   ├── eventbridge.tf      # EventBridge resources
│   ├── batch.tf            # AWS Batch configuration
│   ├── dynamodb.tf         # DynamoDB tables
│   ├── iam.tf              # IAM roles and policies
│   ├── sns.tf              # SNS topics
│   └── variables.tf        # Variable definitions
├── docker/                 # Container configuration
│   ├── Dockerfile          # Multi-stage Docker build
│   ├── pipeline.sh         # Main pipeline script
│   └── scripts/           # Development scripts
│       ├── develop-mvp.sh  # MVP development workflow
│       ├── create-repository.sh
│       ├── deploy-vercel.sh
│       └── ...
├── lambda/                 # Lambda functions
│   ├── update-mvp-status.py
│   └── index.py
├── scripts/               # Utility and test scripts
│   ├── test-event-debug.sh # Comprehensive system test
│   ├── eventbridge-test-cli.sh # CLI testing tool
│   └── eventbridge-policy.json # IAM policy template
├── docs/                  # Documentation
│   ├── mvp-automation-design.md
│   └── EVENTBRIDGE_*.md
└── README.md
```

## 🎯 Core Components

### EventBridge Configuration
- **Event Bus**: `mvp-development`
- **Event Source**: `founderdash.web`
- **Event Type**: `MVP Development Request`

### Batch Job Processing
- **Job Queue**: `founderdash-mvp-job-queue`
- **Job Definition**: `founderdash-mvp-job-definition`
- **Container**: Ubuntu 22.04 with Node.js, Python, AWS CLI, GitHub CLI

### Data Storage
- **DynamoDB Table**: `founderdash-mvp-development-jobs`
- **Job Status Tracking**: Real-time status updates
- **Metadata Storage**: Complete job history and parameters

## 📡 Event Format

Send events to trigger MVP development:

```json
{
  "Source": "founderdash.web",
  "DetailType": "MVP Development Request",
  "Detail": "{\"jobId\": \"unique_job_id\", \"userId\": \"user_123\", \"businessName\": \"My Startup\", \"requirements\": \"Build a SaaS platform\", \"priority\": \"normal\"}",
  "EventBusName": "mvp-development"
}
```

## 🔧 Configuration

### Environment Variables

The system uses these environment variables:

```bash
# AWS Configuration
AWS_REGION=us-east-2
AWS_ACCOUNT_ID=your-account-id

# EventBridge
EVENTBRIDGE_BUS_NAME=mvp-development

# DynamoDB
DYNAMODB_TABLE_NAME=founderdash-mvp-development-jobs

# Container Registry
ECR_REPOSITORY=founderdash/mvp-pipeline

# Notifications
SNS_COMPLETION_TOPIC=founderdash-mvp-completion
```

### Terraform Variables

Key variables in `terraform.tfvars`:

```hcl
project_name = "founderdash-mvp"
environment = "production"
aws_region = "us-east-2"

# Batch Configuration
batch_compute_environment_type = "FARGATE"
batch_max_vcpus = 256
batch_desired_vcpus = 0

# EventBridge Configuration
eventbridge_bus_name = "mvp-development"
```

## 🧪 Testing

### Run Complete System Test
```bash
cd scripts
./test-event-debug.sh
```

### Send Test Event
```bash
cd scripts
./eventbridge-test-cli.sh send
```

### Monitor Job Status
```bash
aws batch list-jobs --job-queue founderdash-mvp-job-queue --region us-east-2
```

### Check DynamoDB Records
```bash
aws dynamodb scan --table-name founderdash-mvp-development-jobs --region us-east-2
```

## 📊 Monitoring and Observability

### CloudWatch Logs
- **EventBridge Logs**: Rule invocations and failures
- **Batch Logs**: Container execution logs at `/aws/batch/mvp-pipeline`
- **Lambda Logs**: Status update function logs

### CloudWatch Metrics
- EventBridge rule matches and invocations
- Batch job submissions and completions
- DynamoDB read/write operations

### SNS Notifications
- Job completion notifications
- Error alerts and failures
- Status change updates

## 🔒 Security

### IAM Roles
- **EventBridge Role**: Permissions to submit Batch jobs
- **Batch Execution Role**: Container execution permissions
- **Batch Task Role**: Application-level AWS permissions
- **Lambda Role**: DynamoDB and SNS permissions

### Network Security
- **VPC Configuration**: Batch runs in default VPC with public subnets
- **Security Groups**: Minimal required access
- **Encryption**: All data encrypted at rest and in transit

## 🚀 Deployment Pipeline

### Development Workflow
1. **Request Reception**: EventBridge receives MVP development request
2. **Job Submission**: Batch job submitted with parsed parameters
3. **Container Execution**: Development container processes the request
4. **Status Updates**: DynamoDB tracking throughout process
5. **Completion Notification**: SNS notification on success/failure

### Container Workflow
1. **Environment Setup**: Prepare development environment
2. **Source Code Analysis**: Parse existing codebase structure
3. **MVP Development**: Execute development using available tools
4. **Quality Assurance**: Run tests and validation
5. **Output Generation**: Create deployable MVP package

## 📝 API Reference

### EventBridge Event Schema
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "jobId": {"type": "string"},
    "userId": {"type": "string"}, 
    "businessName": {"type": "string"},
    "requirements": {"type": "string"},
    "priority": {"type": "string", "enum": ["low", "normal", "high"]},
    "timestamp": {"type": "string", "format": "date-time"}
  },
  "required": ["jobId", "userId", "businessName"]
}
```

### DynamoDB Schema
```json
{
  "jobId": "string (Primary Key)",
  "userId": "string",
  "businessName": "string", 
  "status": "string",
  "createdAt": "string (ISO 8601)",
  "updatedAt": "string (ISO 8601)",
  "batchJobId": "string",
  "requirements": "string",
  "priority": "string",
  "metadata": "map"
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with proper tests
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Check the documentation in `/docs`
- Review CloudWatch logs for debugging
- Test with the provided scripts
- Monitor AWS resource usage and costs

## 🎉 Version History

- **v1.0.0**: Initial release with complete EventBridge → Batch → DynamoDB pipeline
- **v1.1.0**: Added comprehensive testing and monitoring
- **v1.2.0**: Enhanced container with development tools
- **v1.3.0**: Added SNS notifications and status tracking
