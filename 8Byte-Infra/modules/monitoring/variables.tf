variable "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch metrics."
  type        = string
}

variable "application_ports" {
  description = "EC2 host ports for staging and production; also used for ALB health checks."
  type        = map(number)

  validation {
    condition = (
      toset(keys(var.application_ports)) == toset(["staging", "production"]) &&
      length(distinct(values(var.application_ports))) == 2 &&
      alltrue([for port in values(var.application_ports) : port >= 1 && port <= 65535 && port == floor(port)])
    )
    error_message = "application_ports must contain distinct staging and production TCP ports, each an integer from 1 to 65535."
  }
}

variable "aws_region" {
  description = "AWS region for the application infrastructure."
  type        = string
}

variable "ec2_instance_id" {
  description = "Shared application EC2 instance ID."
  type        = string
}

variable "host_metric_namespace" {
  description = "CloudWatch namespace used by the host collector and IAM policy."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "rds_identifier" {
  description = "RDS DB instance identifier used by CloudWatch metrics."
  type        = string
}

variable "target_group_arn_suffixes" {
  description = "Target-group ARN suffixes by environment used by CloudWatch metrics."
  type        = map(string)
}
