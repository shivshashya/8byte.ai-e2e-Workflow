output "cloudwatch_agent_config" {
  description = "Rendered host collector configuration used by bootstrap."
  value       = local.cloudwatch_agent_config
}

output "docker_logging_config" {
  description = "Rendered Docker logging configuration used by bootstrap."
  value       = local.docker_logging_config
}

output "host_metric_namespace" {
  description = "Namespace shared by collection, IAM permissions and dashboards."
  value       = local.host_metric_namespace
}

output "log_groups" {
  description = "System and application log-group names, ARNs and retention."
  value = {
    system = {
      name              = aws_cloudwatch_log_group.system.name
      arn               = aws_cloudwatch_log_group.system.arn
      retention_in_days = aws_cloudwatch_log_group.system.retention_in_days
    }
    application = {
      name              = aws_cloudwatch_log_group.application.name
      arn               = aws_cloudwatch_log_group.application.arn
      retention_in_days = aws_cloudwatch_log_group.application.retention_in_days
    }
  }
}

output "alb_log_bucket" {
  description = "Access-log bucket identifiers and deletion protection."
  value = {
    bucket        = aws_s3_bucket.alb_logs.bucket
    arn           = aws_s3_bucket.alb_logs.arn
    force_destroy = aws_s3_bucket.alb_logs.force_destroy
  }

  # ALB creation checks delivery permissions and requires complete bucket setup.
  depends_on = [
    aws_s3_bucket_policy.alb_logs,
    aws_s3_bucket_server_side_encryption_configuration.alb_logs,
    aws_s3_bucket_ownership_controls.alb_logs,
    aws_s3_bucket_lifecycle_configuration.alb_logs,
  ]
}

output "alb_logs_public_access" {
  description = "Configured public-access protections for the log bucket."
  value = {
    block_public_acls       = aws_s3_bucket_public_access_block.alb_logs.block_public_acls
    block_public_policy     = aws_s3_bucket_public_access_block.alb_logs.block_public_policy
    ignore_public_acls      = aws_s3_bucket_public_access_block.alb_logs.ignore_public_acls
    restrict_public_buckets = aws_s3_bucket_public_access_block.alb_logs.restrict_public_buckets
  }
}

output "alb_logs_encryption_rules" {
  description = "Log bucket encryption configuration."
  value       = aws_s3_bucket_server_side_encryption_configuration.alb_logs.rule
}

output "alb_logs_lifecycle_rules" {
  description = "Log bucket retention configuration."
  value       = aws_s3_bucket_lifecycle_configuration.alb_logs.rule
}

output "alb_logs_policy" {
  description = "Delivery and transport policy for the log bucket."
  value       = aws_s3_bucket_policy.alb_logs.policy
}

output "logging_destinations" {
  description = "Centralized system, application and access-log destinations."
  value = {
    system_group       = aws_cloudwatch_log_group.system.name
    application_group  = aws_cloudwatch_log_group.application.name
    application_stream = "petclinic-<environment>/<container-id>"
    alb_access_logs    = "s3://${aws_s3_bucket.alb_logs.bucket}/alb/AWSLogs/${var.aws_account_id}/"
  }
}
