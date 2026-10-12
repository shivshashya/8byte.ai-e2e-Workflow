variable "availability_zone" {
  description = "Availability Zone for the Single-AZ database."
  type        = string
}

variable "database_secret_suffix" {
  description = "Optional deployment suffix to avoid names reserved by secrets pending deletion. Keep stable for the lifetime of a deployment."
  type        = string

  validation {
    condition     = var.database_secret_suffix == "" || can(regex("^[a-zA-Z0-9_-]{1,40}$", var.database_secret_suffix))
    error_message = "Use an empty suffix or 1-40 letters, digits, underscores or hyphens."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs across two Availability Zones for RDS."
  type        = list(string)
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}

variable "rds_admin_username" {
  description = "Administrative PostgreSQL account; application containers use separate restricted users."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.rds_admin_username))
    error_message = "rds_admin_username must start with a letter and contain at most 63 letters, digits or underscores; AWS also rejects reserved names."
  }
}

variable "rds_backup_retention_days" {
  description = "Days of automated RDS backups retained."
  type        = number

  validation {
    condition     = var.rds_backup_retention_days >= 1 && var.rds_backup_retention_days <= 35 && var.rds_backup_retention_days == floor(var.rds_backup_retention_days)
    error_message = "rds_backup_retention_days must be an integer from 1 to 35."
  }
}

variable "rds_deletion_protection" {
  description = "Block database deletion until explicitly disabled in a reviewed apply."
  type        = bool
}

variable "rds_engine_version" {
  description = "Reviewed PostgreSQL major/minor version; verify class and AZ availability before changing."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.rds_engine_version))
    error_message = "rds_engine_version must use major.minor format, such as 18.4."
  }
}

variable "rds_final_snapshot_identifier" {
  description = "Unique final snapshot name for deletion; null uses petclinic-<project_name>-final. Change it if that snapshot already exists."
  type        = string

  validation {
    condition = var.rds_final_snapshot_identifier == null ? true : (
      can(regex("^[A-Za-z][A-Za-z0-9-]{0,254}$", var.rds_final_snapshot_identifier)) &&
      !endswith(var.rds_final_snapshot_identifier, "-") &&
      !strcontains(var.rds_final_snapshot_identifier, "--")
    )
    error_message = "Snapshot name must start with a letter, use only letters, digits and hyphens, have no consecutive/trailing hyphens, and be at most 255 characters."
  }
}

variable "rds_instance_class" {
  description = "Shared PostgreSQL instance class; db.t3.small has 2 vCPUs and 2 GiB RAM."
  type        = string
}

variable "rds_require_tls" {
  description = "Whether PostgreSQL requires TLS. False permits both TLS and unencrypted connections, as requested."
  type        = bool
}

variable "rds_storage_gib" {
  description = "Encrypted gp3 capacity in GiB; automatic storage scaling is not enabled."
  type        = number

  validation {
    condition     = var.rds_storage_gib >= 20 && var.rds_storage_gib <= 65536 && var.rds_storage_gib == floor(var.rds_storage_gib)
    error_message = "rds_storage_gib must be an integer from 20 to 65536."
  }
}

variable "security_group_id" {
  description = "Security group ID for this service."
  type        = string
}
