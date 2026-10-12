# Pipeline module

GitHub OIDC identity, deployment/notification roles and the SNS failure topic with its email subscription.

Receives repository and immutable GitHub IDs plus ECR, instance and SSH-endpoint identifiers. The notification role can publish only to its topic; the owner must confirm the subscription email.

Compose this module from `8Byte-Infra/main.tf`. AWS provider configuration is
inherited from the root; this directory has no backend or provider block.
All inputs are required here, with deployment defaults held in root
`variables.tf` and overrides in `environments/shared.tfvars`.

## Inputs

| Name | Type | Purpose |
| --- | --- | --- |
| `ec2_instance_arn` | `string` | Shared application EC2 instance ARN for SSH permissions. |
| `ec2_private_ip` | `string` | Application private IPv4 address for tunnel permissions. |
| `ecr_repository_arn` | `string` | Image repository ARN used to scope permissions. |
| `github_owner_id` | `string` | Immutable GitHub repository owner ID, verified through GitHub's OIDC customization API. |
| `github_repository` | `string` | GitHub owner/repository name included alongside immutable IDs in the exact OIDC trust subject. |
| `github_repository_id` | `string` | Immutable GitHub repository ID, verified through GitHub's OIDC customization API. |
| `pipeline_alert_email` | `string` | Owner email for pipeline failure alerts; must confirm the AWS SNS subscription email. |
| `project_name` | `string` | Project name used for resource names and tags. |
| `ssh_endpoint_arn` | `string` | EC2 Instance Connect Endpoint ARN for tunnel permissions. |

## Outputs

| Name | Purpose |
| --- | --- |
| `github_actions_role_arn` | GitHub deployment role ARN. |
| `github_notifications_role_arn` | GitHub failure notification role ARN. |
| `pipeline_failure_topic_arn` | Pipeline failure SNS topic ARN. |
