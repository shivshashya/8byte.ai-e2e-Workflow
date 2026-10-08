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
