# Batch Compute Environment
resource "aws_batch_compute_environment" "mvp_pipeline_compute" {
  compute_environment_name = "${var.project_name}-compute-env"
  type                     = "MANAGED"
  state                    = "ENABLED"
  service_role            = aws_iam_role.batch_service_role.arn

  compute_resources {
    type               = "FARGATE"
    
    max_vcpus = 256
    
    subnets = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.mvp_pipeline_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service_role_policy]

  tags = {
    Name = "${var.project_name}-compute-env"
  }
}

# Batch Job Queue
resource "aws_batch_job_queue" "mvp_pipeline_queue" {
  name     = "${var.project_name}-job-queue"
  state    = "ENABLED"
  priority = 100

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.mvp_pipeline_compute.arn
  }

  tags = {
    Name = "${var.project_name}-job-queue"
  }
}

# Batch Job Definition
resource "aws_batch_job_definition" "mvp_pipeline_job" {
  name = "${var.project_name}-job-definition"
  type = "container"

  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image = var.container_image
    
    resourceRequirements = [
      {
        type  = "VCPU"
        value = "2"
      },
      {
        type  = "MEMORY"
        value = "4096"
      }
    ]

    executionRoleArn = aws_iam_role.batch_execution_role.arn
    jobRoleArn      = aws_iam_role.batch_task_role.arn

    networkConfiguration = {
      assignPublicIp = "ENABLED"
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mvp_pipeline_logs.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "mvp-pipeline"
      }
    }

    environment = [
      {
        name  = "AWS_DEFAULT_REGION"
        value = data.aws_region.current.name
      },
      {
        name  = "DYNAMODB_TABLE"
        value = aws_dynamodb_table.mvp_development_jobs.name
      },
      {
        name  = "COMPLETION_TOPIC"
        value = aws_sns_topic.mvp_completion.arn
      },
      {
        name  = "GITHUB_TOKEN_SECRET"
        value = var.github_token_secret_name
      },
      {
        name  = "SSH_PRIVATE_KEY_SECRET"
        value = var.ssh_private_key_secret_name
      },
      {
        name  = "VERCEL_TOKEN_SECRET"
        value = var.vercel_token_secret_name
      },
      {
        name  = "CLAUDE_API_KEY_SECRET"
        value = var.claude_api_key_secret_name
      },
      {
        name  = "GITHUB_USERNAME"
        value = var.github_username
      },
      {
        name  = "TEMPLATE_REPO"
        value = var.template_repo
      },
      {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
    ]
  })

  retry_strategy {
    attempts = 1
  }

  timeout {
    attempt_duration_seconds = 3600  # 1 hour timeout
  }

  tags = {
    Name = "${var.project_name}-job-definition"
  }

  # Update EventBridge targets when job definition changes
  provisioner "local-exec" {
    when    = create
    command = "../scripts/update-eventbridge-target.sh || true"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Job definition destroyed, manual EventBridge target cleanup may be needed'"
  }
}