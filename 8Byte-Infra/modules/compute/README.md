# Compute module

The shared private EC2 host, its instance profile and scoped ECR, database-secret, log and metric permissions.

Receives subnet/security-group IDs, repository/secret ARNs and collection configuration. The network module's application-subnet output waits for the NAT route, ordering EC2 bootstrap without delaying the independent AMI lookup. The bootstrap template lives in templates/ and contains no database passwords.

Compose this module from `8Byte-Infra/main.tf`. AWS provider configuration is
inherited from the root; this directory has no backend or provider block.
All inputs are required here, with deployment defaults held in root
`variables.tf` and overrides in `environments/shared.tfvars`.

## Inputs

| Name | Type | Purpose |
| --- | --- | --- |
| `cloudwatch_agent_config` | `string` | Rendered JSON configuration for the host metrics and system logs collector. |
| `database_secret_arns` | `map(string)` | Application database secret ARNs by environment; no secret values. |
| `docker_logging_config` | `string` | Rendered Docker daemon JSON configuration for centralized container logs. |
| `ec2_ami_id` | `string` | Pinned Amazon Linux 2023 standard x86_64 AMI, verified in us-east-1. Override when changing region or deliberately upgrading. |
| `ec2_cpu_credit_mode` | `string` | Standard avoids surplus CPU-credit charges but may throttle; unlimited permits paid sustained bursts. |
| `ec2_instance_type` | `string` | x86 T3 instance size for the shared staging and production host. |
| `ec2_root_volume_gb` | `number` | Size in GiB of the encrypted gp3 root disk for Docker images and local logs. |
| `ecr_repository_arn` | `string` | Image repository ARN used to scope permissions. |
| `host_metric_namespace` | `string` | CloudWatch namespace used by the host collector and IAM policy. |
| `log_group_arns` | `map(string)` | System and application log-group ARNs used to scope host writes. |
| `project_name` | `string` | Project name used for resource names and tags. |
| `security_group_id` | `string` | Security group ID for this service. |
| `subnet_id` | `string` | Private subnet ID for the application host. |

## Outputs

| Name | Purpose |
| --- | --- |
| `ec2_instance_id` | Application EC2 instance ID. |
| `ec2_instance_arn` | Application EC2 instance ARN. |
| `ec2_private_ip` | Application private IPv4 address. |
| `user_data` | Rendered bootstrap script for inspection and contract tests; contains no database credentials. |
| `metrics_policy` | Scoped host metric publishing policy. |
| `logs_policy` | Scoped centralized log writing policy. |
