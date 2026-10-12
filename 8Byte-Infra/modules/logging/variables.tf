variable "alb_access_log_retention_days" {
  description = "Days until ALB access-log objects become eligible for S3 lifecycle expiration."
  type        = number
  validation {
    condition     = var.alb_access_log_retention_days >= 1 && var.alb_access_log_retention_days <= 365 && var.alb_access_log_retention_days == floor(var.alb_access_log_retention_days)
    error_message = "ALB access-log retention must be an integer from 1 to 365 days."
  }
}

variable "aws_account_id" {
  description = "AWS account in which Terraform is allowed to manage resources."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS region for the application infrastructure."
  type        = string
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch application and system log retention in days."
  type        = number
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.cloudwatch_log_retention_days)
    error_message = "Choose a supported bounded CloudWatch retention period from 1 to 365 days."
  }
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}
