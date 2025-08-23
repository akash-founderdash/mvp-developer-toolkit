# MVP EventBridge System Makefile

.PHONY: help install deploy build test clean status

# Default target
help:
	@echo "MVP EventBridge System Commands:"
	@echo ""
	@echo "Infrastructure:"
	@echo "  deploy     - Deploy infrastructure with Terraform"
	@echo "  validate   - Validate Terraform configuration" 
	@echo "  plan       - Show Terraform plan"
	@echo "  clean      - Destroy infrastructure"
	@echo ""
	@echo "Container:"
	@echo "  build      - Build Docker container"
	@echo "  push       - Push container to ECR"
	@echo "  container  - Build and push container"
	@echo ""
	@echo "Testing:"
	@echo "  test       - Run complete system test"
	@echo "  test-eb    - Test EventBridge only"
	@echo "  send       - Send test event"
	@echo ""
	@echo "Monitoring:"
	@echo "  status     - Check job status"
	@echo "  logs       - View Batch logs"
	@echo "  metrics    - View CloudWatch metrics"
	@echo ""
	@echo "Setup:"
	@echo "  install    - Install prerequisites"
	@echo "  init       - Initialize Terraform"

# Infrastructure commands
deploy:
	cd infrastructure && terraform apply

validate:
	cd infrastructure && terraform validate

plan:
	cd infrastructure && terraform plan

init:
	cd infrastructure && terraform init

clean:
	cd infrastructure && terraform destroy

# Container commands  
build:
	cd docker && docker build -t mvp-pipeline:latest .

push:
	@echo "Pushing container to ECR..."
	@cd docker && \
	aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-2.amazonaws.com && \
	docker tag mvp-pipeline:latest $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-2.amazonaws.com/founderdash/mvp-pipeline:latest && \
	docker push $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-2.amazonaws.com/founderdash/mvp-pipeline:latest

container: build push

# Testing commands
test:
	cd scripts && chmod +x test-event-debug.sh && ./test-event-debug.sh

test-eb:
	cd scripts && chmod +x eventbridge-test-cli.sh && ./eventbridge-test-cli.sh test-all

send:
	cd scripts && chmod +x eventbridge-test-cli.sh && ./eventbridge-test-cli.sh send

# Monitoring commands
status:
	@aws batch list-jobs --job-queue founderdash-mvp-job-queue --region us-east-2

logs:
	@echo "Recent Batch logs:"
	@aws logs describe-log-streams --log-group-name /aws/batch/mvp-pipeline --region us-east-2 --order-by LastEventTime --descending --max-items 1 --query 'logStreams[0].logStreamName' --output text | xargs -I {} aws logs get-log-events --log-group-name /aws/batch/mvp-pipeline --log-stream-name {} --region us-east-2

metrics:
	@echo "EventBridge metrics (last hour):"
	@aws cloudwatch get-metric-statistics --namespace "AWS/Events" --metric-name "InvocationsCount" --dimensions Name=RuleName,Value=founderdash-mvp-development-rule --start-time $$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $$(date -u +%Y-%m-%dT%H:%M:%S) --period 3600 --statistic Sum --region us-east-2

# Setup commands
install:
	@echo "Checking prerequisites..."
	@which aws || (echo "AWS CLI not found. Please install AWS CLI." && exit 1)
	@which terraform || (echo "Terraform not found. Please install Terraform." && exit 1)  
	@which docker || (echo "Docker not found. Please install Docker." && exit 1)
	@echo "All prerequisites installed ✓"

# Database operations
db-status:
	@aws dynamodb describe-table --table-name founderdash-mvp-development-jobs --region us-east-2 --query 'Table.{Status:TableStatus,Items:ItemCount}' --output table

db-scan:
	@aws dynamodb scan --table-name founderdash-mvp-development-jobs --region us-east-2 --max-items 10

# EventBridge operations
eb-rules:
	@aws events list-rules --event-bus-name mvp-development --region us-east-2 --output table

eb-targets:
	@aws events list-targets-by-rule --rule founderdash-mvp-development-rule --event-bus-name mvp-development --region us-east-2 --output table
