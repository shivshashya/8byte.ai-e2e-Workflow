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
