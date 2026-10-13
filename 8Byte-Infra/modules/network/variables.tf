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

variable "availability_zones" {
  description = "Two distinct Availability Zones, ordered as A then B."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct Availability Zones."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet IPv4 CIDRs, ordered as A then B; must be inside the VPC and not overlap any subnet."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2 && alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "private_subnet_cidrs must contain exactly two valid IPv4 CIDR ranges."
  }
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet IPv4 CIDRs, ordered as A then B; must be inside the VPC and not overlap any subnet."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "public_subnet_cidrs must contain exactly two valid IPv4 CIDR ranges."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR range for the shared VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR range."
  }
}

variable "vpc_name" {
  description = "VPC name displayed in the AWS console through its Name tag."
  type        = string
}
