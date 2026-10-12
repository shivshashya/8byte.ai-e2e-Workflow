variable "access_log_bucket_name" {
  description = "ALB access-log bucket name; the caller must ensure delivery configuration is ready."
  type        = string
}

variable "alb_deletion_protection" {
  description = "Prevent ALB deletion when enabled; disabled by default for assignment cleanup."
  type        = bool
}

variable "alb_health_check_path" {
  description = "Unauthenticated backend health endpoint returning 200 only when the application is healthy."
  type        = string

  validation {
    condition     = startswith(var.alb_health_check_path, "/") && !strcontains(var.alb_health_check_path, "?")
    error_message = "alb_health_check_path must start with / and contain no query string."
  }
}

variable "alb_listener_ports" {
  description = "Public HTTP listener ports on the shared ALB; independent from the EC2 host ports."
  type        = map(number)

  validation {
    condition = (
      toset(keys(var.alb_listener_ports)) == toset(["staging", "production"]) &&
      length(distinct(values(var.alb_listener_ports))) == 2 &&
      alltrue([for port in values(var.alb_listener_ports) : port >= 1 && port <= 65535 && port == floor(port)])
    )
    error_message = "alb_listener_ports must contain distinct staging and production TCP ports, each an integer from 1 to 65535."
  }
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

variable "ec2_instance_id" {
  description = "Shared application EC2 instance ID."
  type        = string
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs across two Availability Zones for the ALB."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for this service."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID supplied by the network module."
  type        = string
}
