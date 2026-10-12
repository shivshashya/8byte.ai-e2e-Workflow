# Database module

Private Single-AZ PostgreSQL RDS and separate staging/production application secret containers.

Receives private subnet IDs and the RDS security group from networking. Exposes endpoints and secret ARNs. Password generation and SQL initialization remain an explicit operator step outside Terraform.

Compose this module from `8Byte-Infra/main.tf`. AWS provider configuration is
inherited from the root; this directory has no backend or provider block.
All inputs are required here, with deployment defaults held in root
`variables.tf` and overrides in `environments/shared.tfvars`.

## Inputs

| Name | Type | Purpose |
| --- | --- | --- |
| `availability_zone` | `string` | Availability Zone for the Single-AZ database. |
| `database_secret_suffix` | `string` | Optional deployment suffix to avoid names reserved by secrets pending deletion. Keep stable for the lifetime of a deployment. |
| `private_subnet_ids` | `list(string)` | Private subnet IDs across two Availability Zones for RDS. |
| `project_name` | `string` | Project name used for resource names and tags. |
| `rds_admin_username` | `string` | Administrative PostgreSQL account; application containers use separate restricted users. |
| `rds_backup_retention_days` | `number` | Days of automated RDS backups retained. |
| `rds_deletion_protection` | `bool` | Block database deletion until explicitly disabled in a reviewed apply. |
| `rds_engine_version` | `string` | Reviewed PostgreSQL major/minor version; verify class and AZ availability before changing. |
| `rds_final_snapshot_identifier` | `string` | Unique final snapshot name for deletion; null uses petclinic-<project_name>-final. Change it if that snapshot already exists. |
| `rds_instance_class` | `string` | Shared PostgreSQL instance class; db.t3.small has 2 vCPUs and 2 GiB RAM. |
| `rds_require_tls` | `bool` | Whether PostgreSQL requires TLS. False permits both TLS and unencrypted connections, as requested. |
| `rds_storage_gib` | `number` | Encrypted gp3 capacity in GiB; automatic storage scaling is not enabled. |
| `security_group_id` | `string` | Security group ID for this service. |

## Outputs

| Name | Purpose |
| --- | --- |
| `rds_instance_id` | RDS provider resource ID. |
| `rds_identifier` | RDS database identifier for metrics. |
| `rds_address` | Private PostgreSQL endpoint. |
| `rds_port` | PostgreSQL TCP port. |
| `rds_admin_secret_arn` | RDS-managed admin secret ARN; never the password. |
| `database_secret_arns` | Application database secret ARNs by environment. |
