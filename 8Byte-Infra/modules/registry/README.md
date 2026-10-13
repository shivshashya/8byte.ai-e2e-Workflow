# Registry module

One immutable ECR repository with push scanning and bounded image retention.

Exposes its repository URL for deployment and its ARN for scoped IAM policies.

Compose this module from `8Byte-Infra/main.tf`. AWS provider configuration is
inherited from the root; this directory has no backend or provider block.
All inputs are required here, with deployment defaults held in root
`variables.tf` and overrides in `environments/shared.tfvars`.

## Inputs

| Name | Type | Purpose |
| --- | --- | --- |
| `ecr_repository_name` | `string` | One private image repository shared by staging and production. |
| `ecr_retained_image_count` | `number` | Keep this many newest ECR images; older images may expire even if deployed. |
| `project_name` | `string` | Project name used for resource names and tags. |

## Outputs

| Name | Purpose |
| --- | --- |
| `repository_url` | Shared application image repository URL. |
| `repository_arn` | Shared application image repository ARN. |
