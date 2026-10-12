# Monitoring module

Infrastructure/database and application CloudWatch dashboards.

Receives instance/database identifiers, ALB/target-group metric dimensions and the collector namespace. Dashboard bodies are exposed for contract verification.

Compose this module from `8Byte-Infra/main.tf`. AWS provider configuration is
inherited from the root; this directory has no backend or provider block.
All inputs are required here, with deployment defaults held in root
`variables.tf` and overrides in `environments/shared.tfvars`.

## Inputs

| Name | Type | Purpose |
| --- | --- | --- |
| `alb_arn_suffix` | `string` | ALB ARN suffix used by CloudWatch metrics. |
| `application_ports` | `map(number)` | EC2 host ports for staging and production; also used for ALB health checks. |
| `aws_region` | `string` | AWS region for the application infrastructure. |
| `ec2_instance_id` | `string` | Shared application EC2 instance ID. |
| `host_metric_namespace` | `string` | CloudWatch namespace used by the host collector and IAM policy. |
| `project_name` | `string` | Project name used for resource names and tags. |
| `rds_identifier` | `string` | RDS DB instance identifier used by CloudWatch metrics. |
| `target_group_arn_suffixes` | `map(string)` | Target-group ARN suffixes by environment used by CloudWatch metrics. |

## Outputs

| Name | Purpose |
| --- | --- |
| `monitoring_dashboards` | CloudWatch console links for both dashboards. |
| `dashboard_bodies` | Rendered JSON for dashboard inspection and contract tests. |
