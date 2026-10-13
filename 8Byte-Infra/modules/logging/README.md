# Logging module

CloudWatch system/application log groups, a private ALB access-log bucket, and rendered host/container collection settings.

Receives account, region, project and retention settings. Exposes collection configuration to compute and bucket settings to the load balancer. It does not depend on compute or the load balancer.

Compose this module from `8Byte-Infra/main.tf`. AWS provider configuration is
inherited from the root; this directory has no backend or provider block.
All inputs are required here, with deployment defaults held in root
`variables.tf` and overrides in `environments/shared.tfvars`.

## Inputs

| Name | Type | Purpose |
| --- | --- | --- |
| `alb_access_log_retention_days` | `number` | Days until ALB access-log objects become eligible for S3 lifecycle expiration. |
| `aws_account_id` | `string` | AWS account in which Terraform is allowed to manage resources. |
| `aws_region` | `string` | AWS region for the application infrastructure. |
| `cloudwatch_log_retention_days` | `number` | CloudWatch application and system log retention in days. |
| `project_name` | `string` | Project name used for resource names and tags. |

## Outputs

| Name | Purpose |
| --- | --- |
| `cloudwatch_agent_config` | Rendered host collector configuration used by bootstrap. |
| `docker_logging_config` | Rendered Docker logging configuration used by bootstrap. |
| `host_metric_namespace` | Namespace shared by collection, IAM permissions and dashboards. |
| `log_groups` | System and application log-group names, ARNs and retention. |
| `alb_log_bucket` | Access-log bucket identifiers and deletion protection. |
| `alb_logs_public_access` | Configured public-access protections for the log bucket. |
| `alb_logs_encryption_rules` | Log bucket encryption configuration. |
| `alb_logs_lifecycle_rules` | Log bucket retention configuration. |
| `alb_logs_policy` | Delivery and transport policy for the log bucket. |
| `logging_destinations` | Centralized system, application and access-log destinations. |
