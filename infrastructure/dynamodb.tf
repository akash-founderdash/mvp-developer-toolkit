# DynamoDB table for MVP development jobs
resource "aws_dynamodb_table" "mvp_development_jobs" {
  name           = "${var.project_name}-development-jobs"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "jobId"

  attribute {
    name = "jobId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  # Global Secondary Index for querying jobs by user
  global_secondary_index {
    name            = "user-jobs-index"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-development-jobs"
    Environment = var.environment
  }
}

# DynamoDB table for job status tracking (optional - can use main table)
resource "aws_dynamodb_table" "mvp_development_status" {
  name           = "${var.project_name}-development-status"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "projectId"

  attribute {
    name = "projectId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  # Global Secondary Index for querying status by user
  global_secondary_index {
    name            = "user-status-index"
    hash_key        = "userId"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup of old status records (optional)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-development-status"
    Environment = var.environment
  }
}