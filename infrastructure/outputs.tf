output "eventbridge_bus_name" {
  description = "Name of the EventBridge custom bus"
  value       = aws_cloudwatch_event_bus.mvp_development.name
}

output "eventbridge_bus_arn" {
  description = "ARN of the EventBridge custom bus"
  value       = aws_cloudwatch_event_bus.mvp_development.arn
}

output "batch_job_queue_name" {
  description = "Name of the Batch job queue"
  value       = aws_batch_job_queue.mvp_pipeline_queue.name
}

output "batch_job_queue_arn" {
  description = "ARN of the Batch job queue"
  value       = aws_batch_job_queue.mvp_pipeline_queue.arn
}

output "batch_job_definition_name" {
  description = "Name of the Batch job definition"
  value       = aws_batch_job_definition.mvp_pipeline_job.name
}

output "batch_job_definition_arn" {
  description = "ARN of the Batch job definition"
  value       = aws_batch_job_definition.mvp_pipeline_job.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.mvp_pipeline_logs.name
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = aws_sqs_queue.mvp_pipeline_dlq.url
}

output "security_group_id" {
  description = "ID of the security group for Fargate tasks"
  value       = aws_security_group.mvp_pipeline_sg.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for MVP jobs"
  value       = aws_dynamodb_table.mvp_development_jobs.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS completion topic"
  value       = aws_sns_topic.mvp_completion.arn
}

output "lambda_function_name" {
  description = "Name of the status update Lambda function"
  value       = aws_lambda_function.update_mvp_status.function_name
}