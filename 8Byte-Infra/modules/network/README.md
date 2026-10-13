# Network module

VPC, two public and two private subnets, route tables, one NAT gateway, security groups and the private SSH endpoint.

Uses the root networking inputs. Exposes subnet IDs, security-group IDs and endpoint identifiers to the service modules.

Compose this module from `8Byte-Infra/main.tf`. AWS provider configuration is
inherited from the root; this directory has no backend or provider block.
All inputs are required here, with deployment defaults held in root
`variables.tf` and overrides in `environments/shared.tfvars`.

## Inputs

| Name | Type | Purpose |
| --- | --- | --- |
| `alb_listener_ports` | `map(number)` | Public HTTP listener ports on the shared ALB; independent from the EC2 host ports. |
| `application_ports` | `map(number)` | EC2 host ports for staging and production; also used for ALB health checks. |
| `availability_zones` | `list(string)` | Two distinct Availability Zones, ordered as A then B. |
| `private_subnet_cidrs` | `list(string)` | Private subnet IPv4 CIDRs, ordered as A then B; must be inside the VPC and not overlap any subnet. |
| `project_name` | `string` | Project name used for resource names and tags. |
| `public_subnet_cidrs` | `list(string)` | Public subnet IPv4 CIDRs, ordered as A then B; must be inside the VPC and not overlap any subnet. |
| `vpc_cidr` | `string` | IPv4 CIDR range for the shared VPC. |
| `vpc_name` | `string` | VPC name displayed in the AWS console through its Name tag. |

## Outputs

| Name | Purpose |
| --- | --- |
| `vpc_id` | Shared VPC ID. |
| `vpc_cidr` | Shared VPC IPv4 range. |
| `public_subnet_ids` | Public subnet IDs, ordered by logical Availability Zone. |
| `private_subnet_ids` | Private subnet IDs, ordered by logical Availability Zone. |
| `application_subnet_id` | Private subnet A ID after the NAT route is ready for bootstrap downloads. |
| `internet_gateway_id` | Internet gateway ID. |
| `route_table_ids` | Public and private route-table IDs. |
| `security_group_ids` | Security groups for each traffic boundary. |
| `ssh_endpoint_id` | SSH endpoint ID. |
| `ssh_endpoint_arn` | SSH endpoint ARN for IAM policies. |
| `nat_gateway_id` | NAT gateway ID. |
| `nat_public_ip` | NAT public IPv4 address. |
