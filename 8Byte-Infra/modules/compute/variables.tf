variable "cloudwatch_agent_config" {
  description = "Rendered JSON configuration for the host metrics and system logs collector."
  type        = string
}

variable "database_secret_arns" {
  description = "Application database secret ARNs by environment; no secret values."
  type        = map(string)
}

variable "docker_logging_config" {
  description = "Rendered Docker daemon JSON configuration for centralized container logs."
  type        = string
}

variable "ec2_ami_id" {
  description = "Pinned Amazon Linux 2023 standard x86_64 AMI, verified in us-east-1. Override when changing region or deliberately upgrading."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.ec2_ami_id))
    error_message = "ec2_ami_id must be a valid AMI ID."
  }
}

variable "ec2_cpu_credit_mode" {
  description = "Standard avoids surplus CPU-credit charges but may throttle; unlimited permits paid sustained bursts."
  type        = string

  validation {
    condition     = contains(["standard", "unlimited"], var.ec2_cpu_credit_mode)
    error_message = "ec2_cpu_credit_mode must be standard or unlimited."
  }
}

variable "ec2_instance_type" {
  description = "x86 T3 instance size for the shared staging and production host."
  type        = string

  validation {
    condition     = startswith(var.ec2_instance_type, "t3.")
    error_message = "ec2_instance_type must be an x86 T3 instance such as t3.medium; AMI and CPU-credit configuration must be reviewed for another family."
  }
}

variable "ec2_root_volume_gb" {
  description = "Size in GiB of the encrypted gp3 root disk for Docker images and local logs."
  type        = number

  validation {
    condition     = var.ec2_root_volume_gb >= 30 && var.ec2_root_volume_gb == floor(var.ec2_root_volume_gb)
    error_message = "ec2_root_volume_gb must be an integer of at least 30 GiB."
  }
}

variable "ecr_repository_arn" {
  description = "Image repository ARN used to scope permissions."
  type        = string
}

variable "host_metric_namespace" {
  description = "CloudWatch namespace used by the host collector and IAM policy."
  type        = string
}

variable "log_group_arns" {
  description = "System and application log-group ARNs used to scope host writes."
  type        = map(string)
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for this service."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for the application host."
  type        = string
}
