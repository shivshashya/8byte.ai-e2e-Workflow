# Load Balancer module

One public ALB with staging/production HTTP listeners, separate target groups, health checks and public management-path blocking.

Receives public subnet IDs, the ALB security group, the EC2 target and the logging bucket. The subnet and bucket outputs wait for routing and log delivery configuration before ALB creation.

Compose this module from `8Byte-Infra/main.tf`. AWS provider configuration is
inherited from the root; this directory has no backend or provider block.
All inputs are required here, with deployment defaults held in root
`variables.tf` and overrides in `environments/shared.tfvars`.

## Inputs

| Name | Type | Purpose |
| --- | --- | --- |
| `access_log_bucket_name` | `string` | ALB access-log bucket name; the caller must ensure delivery configuration is ready. |
| `alb_deletion_protection` | `bool` | Prevent ALB deletion when enabled; disabled by default for assignment cleanup. |
| `alb_health_check_path` | `string` | Unauthenticated backend health endpoint returning 200 only when the application is healthy. |
| `alb_listener_ports` | `map(number)` | Public HTTP listener ports on the shared ALB; independent from the EC2 host ports. |
| `application_ports` | `map(number)` | EC2 host ports for staging and production; also used for ALB health checks. |
| `ec2_instance_id` | `string` | Shared application EC2 instance ID. |
| `project_name` | `string` | Project name used for resource names and tags. |
| `public_subnet_ids` | `list(string)` | Public subnet IDs across two Availability Zones for the ALB. |
| `security_group_id` | `string` | Security group ID for this service. |
| `vpc_id` | `string` | VPC ID supplied by the network module. |

## Outputs

| Name | Purpose |
| --- | --- |
| `alb_dns_name` | Public ALB DNS name. |
| `alb_arn` | ALB ARN. |
| `alb_arn_suffix` | ALB ARN suffix for metrics. |
| `target_group_arns` | Target-group ARNs by environment. |
| `target_group_arn_suffixes` | Target-group ARN suffixes for metrics. |
| `access_logs` | ALB access-log delivery configuration. |
| `application_urls` | Public application URLs by environment. |
