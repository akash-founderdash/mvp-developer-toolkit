# SNS topic for MVP completion notifications
resource "aws_sns_topic" "mvp_completion" {
  name = "${var.project_name}-completion"

  tags = {
    Name = "${var.project_name}-completion"
    Environment = var.environment
  }
}

# SNS topic policy to allow publishing from Batch tasks
resource "aws_sns_topic_policy" "mvp_completion_policy" {
  arn = aws_sns_topic.mvp_completion.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.batch_task_role.arn
        }
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.mvp_completion.arn
      }
    ]
  })
}

# Lambda function for processing completion notifications
resource "aws_lambda_function" "update_mvp_status" {
  filename         = "../lambda/update-mvp-status.zip"
  function_name    = "${var.project_name}-update-status"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.mvp_development_jobs.name
      STATUS_TABLE   = aws_dynamodb_table.mvp_development_status.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs,
  ]

  tags = {
    Name = "${var.project_name}-update-status"
    Environment = var.environment
  }
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-update-status"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# SNS subscription to trigger Lambda
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.mvp_completion.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.update_mvp_status.arn
}

# Lambda permission for SNS to invoke
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_mvp_status.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.mvp_completion.arn
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-execution-role"
  }
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda DynamoDB access policy
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.project_name}-lambda-dynamodb-policy"
  description = "Policy for Lambda to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = [
          aws_dynamodb_table.mvp_development_jobs.arn,
          aws_dynamodb_table.mvp_development_status.arn
        ]
      }
    ]
  })
}

# Attach DynamoDB policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}