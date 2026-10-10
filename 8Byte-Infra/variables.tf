variable "cloudwatch_log_retention_days" {
  description = "CloudWatch application and system log retention in days."
  type        = number
  default     = 14
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.cloudwatch_log_retention_days)
    error_message = "Choose a supported bounded CloudWatch retention period from 1 to 365 days."
  }
}

variable "alb_access_log_retention_days" {
  description = "Days until ALB access-log objects become eligible for S3 lifecycle expiration."
  type        = number
  default     = 30
  validation {
    condition     = var.alb_access_log_retention_days >= 1 && var.alb_access_log_retention_days <= 365 && var.alb_access_log_retention_days == floor(var.alb_access_log_retention_days)
    error_message = "ALB access-log retention must be an integer from 1 to 365 days."
  }
}

variable "aws_region" {
  description = "AWS region for the application infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account in which Terraform is allowed to manage resources."
  type        = string
  default     = "239799717936"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "database_secret_suffix" {
  description = "Optional deployment suffix to avoid names reserved by secrets pending deletion. Keep stable for the lifetime of a deployment."
  type        = string
  default     = "1010202601"

  validation {
    condition     = var.database_secret_suffix == "" || can(regex("^[a-zA-Z0-9_-]{1,40}$", var.database_secret_suffix))
    error_message = "Use an empty suffix or 1-40 letters, digits, underscores or hyphens."
  }
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "8byte-devops"
}

variable "vpc_name" {
  description = "VPC name displayed in the AWS console through its Name tag."
  type        = string
  default     = "8byte-ai-vpc"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR range for the shared VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR range."
  }
}

variable "availability_zones" {
  description = "Two distinct Availability Zones, ordered as A then B."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet IPv4 CIDRs, ordered as A then B; must be inside the VPC and not overlap any subnet."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "public_subnet_cidrs must contain exactly two valid IPv4 CIDR ranges."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet IPv4 CIDRs, ordered as A then B; must be inside the VPC and not overlap any subnet."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2 && alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "private_subnet_cidrs must contain exactly two valid IPv4 CIDR ranges."
  }
}

variable "application_ports" {
  description = "EC2 host ports for staging and production; also used for ALB health checks."
  type        = map(number)
  default = {
    staging    = 8081
    production = 8082
  }

  validation {
    condition = (
      toset(keys(var.application_ports)) == toset(["staging", "production"]) &&
      length(distinct(values(var.application_ports))) == 2 &&
      alltrue([for port in values(var.application_ports) : port >= 1 && port <= 65535 && port == floor(port)])
    )
    error_message = "application_ports must contain distinct staging and production TCP ports, each an integer from 1 to 65535."
  }
}

variable "alb_listener_ports" {
  description = "Public HTTP listener ports on the shared ALB; independent from the EC2 host ports."
  type        = map(number)
  default = {
    staging    = 8081
    production = 80
  }

  validation {
    condition = (
      toset(keys(var.alb_listener_ports)) == toset(["staging", "production"]) &&
      length(distinct(values(var.alb_listener_ports))) == 2 &&
      alltrue([for port in values(var.alb_listener_ports) : port >= 1 && port <= 65535 && port == floor(port)])
    )
    error_message = "alb_listener_ports must contain distinct staging and production TCP ports, each an integer from 1 to 65535."
  }
}

variable "alb_health_check_path" {
  description = "Unauthenticated backend health endpoint returning 200 only when the application is healthy."
  type        = string
  default     = "/actuator/health"

  validation {
    condition     = startswith(var.alb_health_check_path, "/") && !strcontains(var.alb_health_check_path, "?")
    error_message = "alb_health_check_path must start with / and contain no query string."
  }
}

variable "alb_deletion_protection" {
  description = "Prevent ALB deletion when enabled; disabled by default for assignment cleanup."
  type        = bool
  default     = false
}

variable "ec2_instance_type" {
  description = "x86 T3 instance size for the shared staging and production host."
  type        = string
  default     = "t3.medium"

  validation {
    condition     = startswith(var.ec2_instance_type, "t3.")
    error_message = "ec2_instance_type must be an x86 T3 instance such as t3.medium; AMI and CPU-credit configuration must be reviewed for another family."
  }
}

variable "ec2_ami_id" {
  description = "Pinned Amazon Linux 2023 standard x86_64 AMI, verified in us-east-1. Override when changing region or deliberately upgrading."
  type        = string
  default     = "ami-0d27e0fb3bac4d724"

  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.ec2_ami_id))
    error_message = "ec2_ami_id must be a valid AMI ID."
  }
}

variable "ec2_root_volume_gb" {
  description = "Size in GiB of the encrypted gp3 root disk for Docker images and local logs."
  type        = number
  default     = 30

  validation {
    condition     = var.ec2_root_volume_gb >= 30 && var.ec2_root_volume_gb == floor(var.ec2_root_volume_gb)
    error_message = "ec2_root_volume_gb must be an integer of at least 30 GiB."
  }
}

variable "ec2_cpu_credit_mode" {
  description = "Standard avoids surplus CPU-credit charges but may throttle; unlimited permits paid sustained bursts."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "unlimited"], var.ec2_cpu_credit_mode)
    error_message = "ec2_cpu_credit_mode must be standard or unlimited."
  }
}

variable "rds_engine_version" {
  description = "Reviewed PostgreSQL major/minor version; verify class and AZ availability before changing."
  type        = string
  default     = "18.4"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.rds_engine_version))
    error_message = "rds_engine_version must use major.minor format, such as 18.4."
  }
}

variable "rds_instance_class" {
  description = "Shared PostgreSQL instance class; db.t3.small has 2 vCPUs and 2 GiB RAM."
  type        = string
  default     = "db.t3.small"
}

variable "rds_storage_gib" {
  description = "Encrypted gp3 capacity in GiB; automatic storage scaling is not enabled."
  type        = number
  default     = 20

  validation {
    condition     = var.rds_storage_gib >= 20 && var.rds_storage_gib <= 65536 && var.rds_storage_gib == floor(var.rds_storage_gib)
    error_message = "rds_storage_gib must be an integer from 20 to 65536."
  }
}

variable "rds_admin_username" {
  description = "Administrative PostgreSQL account; application containers use separate restricted users."
  type        = string
  default     = "db_admin"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.rds_admin_username))
    error_message = "rds_admin_username must start with a letter and contain at most 63 letters, digits or underscores; AWS also rejects reserved names."
  }
}

variable "rds_backup_retention_days" {
  description = "Days of automated RDS backups retained."
  type        = number
  default     = 7

  validation {
    condition     = var.rds_backup_retention_days >= 1 && var.rds_backup_retention_days <= 35 && var.rds_backup_retention_days == floor(var.rds_backup_retention_days)
    error_message = "rds_backup_retention_days must be an integer from 1 to 35."
  }
}

variable "rds_require_tls" {
  description = "Whether PostgreSQL requires TLS. False permits both TLS and unencrypted connections, as requested."
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Block database deletion until explicitly disabled in a reviewed apply."
  type        = bool
  default     = true
}

variable "rds_final_snapshot_identifier" {
  description = "Unique final snapshot name for deletion; null uses petclinic-<project_name>-final. Change it if that snapshot already exists."
  type        = string
  default     = null

  validation {
    condition = var.rds_final_snapshot_identifier == null ? true : (
      can(regex("^[A-Za-z][A-Za-z0-9-]{0,254}$", var.rds_final_snapshot_identifier)) &&
      !endswith(var.rds_final_snapshot_identifier, "-") &&
      !strcontains(var.rds_final_snapshot_identifier, "--")
    )
    error_message = "Snapshot name must start with a letter, use only letters, digits and hyphens, have no consecutive/trailing hyphens, and be at most 255 characters."
  }
}

variable "ecr_repository_name" {
  description = "One private image repository shared by staging and production."
  type        = string
  default     = "8byte-petclinic"
}

variable "ecr_retained_image_count" {
  description = "Keep this many newest ECR images; older images may expire even if deployed."
  type        = number
  default     = 30

  validation {
    condition     = var.ecr_retained_image_count >= 1 && var.ecr_retained_image_count == floor(var.ecr_retained_image_count)
    error_message = "ecr_retained_image_count must be a positive integer."
  }
}

variable "github_repository" {
  description = "GitHub owner/repository name included alongside immutable IDs in the exact OIDC trust subject."
  type        = string
  default     = "shivshashya/8byte.ai-e2e-Workflow"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use owner/repository format without wildcards."
  }
}

variable "github_owner_id" {
  description = "Immutable GitHub repository owner ID, verified through GitHub's OIDC customization API."
  type        = string
  default     = "109200716"

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_owner_id))
    error_message = "github_owner_id must be a positive numeric GitHub owner ID."
  }
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID, verified through GitHub's OIDC customization API."
  type        = string
  default     = "1410967056"

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_repository_id))
    error_message = "github_repository_id must be a positive numeric GitHub repository ID."
  }
}

variable "pipeline_alert_email" {
  description = "Owner email for pipeline failure alerts; must confirm the AWS SNS subscription email."
  type        = string
  default     = "shivshashyadev@gmail.com"

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.pipeline_alert_email))
    error_message = "pipeline_alert_email must be an email address."
  }
}
