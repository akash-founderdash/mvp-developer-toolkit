# EventBridge Rule for MVP Development Events
resource "aws_cloudwatch_event_rule" "mvp_development_rule" {
  name           = "${var.project_name}-development-rule"
  description    = "Rule to trigger MVP development pipeline"
  event_bus_name = aws_cloudwatch_event_bus.mvp_development.name

  event_pattern = jsonencode({
    source      = ["founderdash.web"]
    detail-type = ["MVP Development Request"]
  })

  tags = {
    Name = "${var.project_name}-development-rule"
  }
}

# EventBridge Target - Batch Job
resource "aws_cloudwatch_event_target" "batch_target" {
  rule           = aws_cloudwatch_event_rule.mvp_development_rule.name
  event_bus_name = aws_cloudwatch_event_bus.mvp_development.name
  target_id      = "BatchJobTarget"
  arn            = aws_batch_job_queue.mvp_pipeline_queue.arn
  role_arn       = aws_iam_role.eventbridge_role.arn

  batch_target {
    job_definition = aws_batch_job_definition.mvp_pipeline_job.name
    job_name       = "${var.project_name}-job"
  }

  input_transformer {
    input_paths = {
      jobId = "$.detail.jobId"
    }

    input_template = jsonencode({
      Parameters = {
        JOB_ID = "<jobId>"
      }
    })
  }
}

# Dead Letter Queue for failed events
resource "aws_sqs_queue" "mvp_pipeline_dlq" {
  name = "${var.project_name}-dlq"

  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name = "${var.project_name}-dlq"
  }
}

# EventBridge Rule for failed events
resource "aws_cloudwatch_event_rule" "mvp_development_dlq_rule" {
  name           = "${var.project_name}-dlq-rule"
  description    = "Rule to capture failed MVP development events"
  event_bus_name = aws_cloudwatch_event_bus.mvp_development.name

  event_pattern = jsonencode({
    source      = ["aws.batch"]
    detail-type = ["Batch Job State Change"]
    detail = {
      jobStatus = ["FAILED"]
      jobQueue  = [aws_batch_job_queue.mvp_pipeline_queue.name]
    }
  })

  tags = {
    Name = "${var.project_name}-dlq-rule"
  }
}

# EventBridge Target - SQS DLQ
resource "aws_cloudwatch_event_target" "dlq_target" {
  rule           = aws_cloudwatch_event_rule.mvp_development_dlq_rule.name
  event_bus_name = aws_cloudwatch_event_bus.mvp_development.name
  target_id      = "DLQTarget"
  arn            = aws_sqs_queue.mvp_pipeline_dlq.arn
}