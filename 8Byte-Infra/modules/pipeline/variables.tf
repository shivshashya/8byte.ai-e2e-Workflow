variable "ec2_instance_arn" {
  description = "Shared application EC2 instance ARN for SSH permissions."
  type        = string
}

variable "ec2_private_ip" {
  description = "Application private IPv4 address for tunnel permissions."
  type        = string
}

variable "ecr_repository_arn" {
  description = "Image repository ARN used to scope permissions."
  type        = string
}

variable "github_owner_id" {
  description = "Immutable GitHub repository owner ID, verified through GitHub's OIDC customization API."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_owner_id))
    error_message = "github_owner_id must be a positive numeric GitHub owner ID."
  }
}

variable "github_repository" {
  description = "GitHub owner/repository name included alongside immutable IDs in the exact OIDC trust subject."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use owner/repository format without wildcards."
  }
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID, verified through GitHub's OIDC customization API."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_repository_id))
    error_message = "github_repository_id must be a positive numeric GitHub repository ID."
  }
}

variable "pipeline_alert_email" {
  description = "Owner email for pipeline failure alerts; must confirm the AWS SNS subscription email."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.pipeline_alert_email))
    error_message = "pipeline_alert_email must be an email address."
  }
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "ssh_endpoint_arn" {
  description = "EC2 Instance Connect Endpoint ARN for tunnel permissions."
  type        = string
}
