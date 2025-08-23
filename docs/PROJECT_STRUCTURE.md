# Project Structure

This document describes the complete structure of the MVP EventBridge System.

## 📁 Directory Structure

```
mvp-eventbridge-system/
├── 📄 README.md                    # Main documentation
├── 📄 LICENSE                      # MIT License
├── 📄 package.json                 # NPM package configuration
├── 📄 Makefile                     # Build and deployment commands
├── 📄 .gitignore                   # Git ignore patterns
├── 📄 setup.sh                     # Initial setup script
│
├── 📁 infrastructure/              # Terraform Infrastructure as Code
│   ├── 📄 main.tf                  # Main Terraform configuration
│   ├── 📄 variables.tf             # Variable definitions
│   ├── 📄 outputs.tf               # Output definitions
│   ├── 📄 terraform.tfvars.example # Example variables file
│   ├── 📄 eventbridge.tf           # EventBridge resources
│   ├── 📄 batch.tf                 # AWS Batch configuration
│   ├── 📄 dynamodb.tf              # DynamoDB tables
│   ├── 📄 iam.tf                   # IAM roles and policies
│   ├── 📄 sns.tf                   # SNS topics and subscriptions
│   └── 📄 secrets.tf               # AWS Secrets Manager
│
├── 📁 docker/                      # Container configuration
│   ├── 📄 Dockerfile               # Multi-stage container build
│   ├── 📄 .dockerignore            # Docker ignore patterns
│   ├── 📄 pipeline.sh              # Main pipeline orchestrator
│   ├── 📄 push-to-ecr.sh           # ECR deployment script
│   └── 📁 scripts/                 # Container execution scripts
│       ├── 📄 develop-mvp.sh       # Main MVP development workflow
│       ├── 📄 clone-repository.sh  # Repository cloning
│       ├── 📄 clone-template.sh    # Template cloning
│       ├── 📄 create-repository.sh # GitHub repository creation
│       ├── 📄 deploy-vercel.sh     # Vercel deployment
│       ├── 📄 fetch-job-data.py    # DynamoDB job data fetcher
│       ├── 📄 install-claude.sh    # Claude installation
│       └── 📄 update-job-status.py # Job status updater
│
├── 📁 lambda/                      # Lambda functions
│   ├── 📄 index.py                 # Lambda entry point
│   ├── 📄 update-mvp-status.py     # Status update function
│   └── 📄 update-mvp-status.zip    # Deployment package
│
├── 📁 scripts/                     # Utility and testing scripts
│   ├── 📄 test-event-debug.sh      # Comprehensive system test
│   ├── 📄 eventbridge-test-cli.sh  # EventBridge CLI tool
│   ├── 📄 eventbridge-batch-debug.sh # Batch debugging
│   └── 📄 eventbridge-policy.json  # IAM policy template
│
└── 📁 docs/                        # Documentation
    ├── 📄 mvp-automation-design.md # System design document
    ├── 📄 EVENTBRIDGE_DEPLOYMENT.md # Deployment guide
    ├── 📄 EVENTBRIDGE_DIAGNOSIS.md # Troubleshooting guide
    ├── 📄 EVENTBRIDGE_README.md    # EventBridge specifics
    └── 📄 EVENTBRIDGE_SUCCESS_GUIDE.md # Success metrics
```

## 🎯 Component Responsibilities

### Infrastructure (`/infrastructure/`)
- **Terraform IaC**: Complete AWS resource provisioning
- **EventBridge**: Custom event bus and rules
- **AWS Batch**: Job queue and compute environment
- **DynamoDB**: Job tracking and metadata storage
- **IAM**: Security roles and policies
- **SNS**: Notification system

### Container (`/docker/`)
- **Base Image**: Ubuntu 22.04 with development tools
- **Runtime**: Node.js, Python, AWS CLI, GitHub CLI
- **Scripts**: MVP development automation
- **Pipeline**: Orchestrated execution workflow

### Lambda (`/lambda/`)
- **Status Updates**: Real-time job status tracking
- **Event Processing**: EventBridge event handling
- **Notifications**: SNS integration

### Scripts (`/scripts/`)
- **Testing**: Comprehensive system validation
- **Debugging**: Troubleshooting and diagnostics
- **CLI Tools**: Command-line interfaces

### Documentation (`/docs/`)
- **Design**: System architecture and design
- **Deployment**: Step-by-step guides
- **Troubleshooting**: Common issues and solutions

## 🚀 Key Entry Points

### For Developers
1. **`setup.sh`** - Initial system setup
2. **`Makefile`** - All common operations
3. **`scripts/test-event-debug.sh`** - System testing

### For Operations
1. **`infrastructure/`** - Infrastructure management
2. **`docker/push-to-ecr.sh`** - Container deployment
3. **`scripts/eventbridge-test-cli.sh`** - Operational testing

### For Integration
1. **EventBridge Events** - Send to `mvp-development` bus
2. **DynamoDB Queries** - Job status and history
3. **SNS Subscriptions** - Completion notifications

## 🔧 Configuration Files

- **`terraform.tfvars`** - Infrastructure configuration
- **`package.json`** - Project metadata and scripts
- **`.gitignore`** - Version control exclusions
- **`Dockerfile`** - Container build instructions

## 📊 Data Flow

1. **Event Reception**: EventBridge receives MVP request
2. **Job Submission**: Batch job triggered with parameters
3. **Container Execution**: Development pipeline runs
4. **Status Tracking**: DynamoDB updates throughout
5. **Completion**: SNS notification sent

## 🛠️ Development Workflow

1. **Setup**: Run `./setup.sh`
2. **Configure**: Edit `infrastructure/terraform.tfvars`
3. **Deploy**: Run `make deploy`
4. **Build**: Run `make container`
5. **Test**: Run `make test`
6. **Monitor**: Use `make status` and `make logs`

## 🔒 Security Considerations

- **IAM Roles**: Least privilege access
- **VPC Configuration**: Network isolation
- **Secrets Management**: AWS Secrets Manager integration
- **Encryption**: Data encrypted at rest and in transit

## 📈 Scalability Features

- **Auto Scaling**: Batch compute environment scales automatically
- **Fargate**: Serverless container execution
- **Event-Driven**: Reactive architecture
- **Parallel Processing**: Multiple jobs can run concurrently

## 🧪 Testing Strategy

- **Unit Tests**: Individual component validation
- **Integration Tests**: End-to-end workflow testing
- **Load Tests**: Performance and scalability validation
- **Monitoring**: Real-time observability
