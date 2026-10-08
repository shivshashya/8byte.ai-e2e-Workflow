# Infrastructure: networking and shared application host

This configuration defines the shared VPC, four subnets, an internet gateway,
route tables, four security groups, and an EC2 Instance Connect Endpoint for
SSH. The user applied the network foundation; read-only AWS checks verified
the resources and routing afterward. The reviewed security groups and SSH
endpoint have also been applied and verified in AWS. The NAT gateway, its
Elastic IP, and private-A default route have also been applied and verified.
The SSH-only EC2 host is configured and planned, but has not been
applied. RDS and ALB remain for subsequent reviewed steps.

## Files

| File | Purpose |
| --- | --- |
| `backend.tf` | Store shared infrastructure state in the existing S3 bucket and enable native S3 locking. |
| `versions.tf` | Define compatible Terraform and AWS provider versions. |
| `providers.tf` | Configure AWS region, permitted account, and default resource tags. |
| `main.tf` | Define the VPC. |
| `subnets.tf` | Define two public and two private subnet allocations across two Availability Zones. |
| `routing.tf` | Attach the internet gateway, define the public default route and three route tables, and explicitly associate every subnet. |
| `nat.tf` | Define one Elastic IP and one public zonal NAT gateway in public subnet A. |
| `security_groups.tf` | Define four security groups and explicit inbound/outbound rules. |
| `ssh_access.tf` | Define the SSH endpoint in private subnet A. |
| `ec2.tf` | Verify the pinned AMI and define the shared private application host. |
| `scripts/bootstrap_ec2.sh` | First-boot installation of Docker and deployment tools, service startup, and local log rotation. |
| `variables.tf` | Define configurable region, account, names, CIDRs, Availability Zones, and staging/production host ports. |
| `outputs.tf` | Expose network IDs, security group IDs, SSH endpoint ID, NAT gateway ID, and NAT public IP after an apply. |
| `.terraform.lock.hcl` | Generated during initialization; records the selected provider version and checksums. Commit this file. |

All top-level `.tf` files in `8Byte-Infra/` form one Terraform root module.
File names organize the code for readers; resource references determine
dependencies. Moving the provider block between files in the same directory
does not change resource addresses or AWS settings. Keep this single root
module for the shared infrastructure. Add
`rds.tf` and `alb.tf` as their implementation steps are approved; reusable
child modules are optional later.

## Subnet layout

| Subnet | CIDR | Availability Zone | Intended use |
| --- | --- | --- | --- |
| Public A | `10.0.0.0/24` | `us-east-1a` | Internet-facing ALB and the deployed NAT gateway. |
| Public B | `10.0.1.0/24` | `us-east-1b` | Internet-facing ALB. |
| Private A | `10.0.10.0/24` | `us-east-1a` | Shared EC2 host and single-AZ RDS placement. |
| Private B | `10.0.11.0/24` | `us-east-1b` | Second subnet for the RDS subnet group. |

`us-east-1a` and `us-east-1b` were verified as available in the configured
account. Every subnet references `aws_vpc.vpc_8byte_ai.id`, so Terraform knows it must
create the VPC before the subnets. List index `[0]` selects A and `[1]` selects B.

The public subnet route table now defines a direct default route to the
internet gateway. Automatic public IP assignment is disabled on all four
subnets; the planned internet-facing ALB manages its own public addresses.

The default subnet CIDRs are within the VPC and do not overlap. Variable
validation checks the list sizes and IPv4 syntax; it does not verify overlap
or containment. Review those properties when changing CIDRs.

## VPC naming

- Terraform resource address: `aws_vpc.vpc_8byte_ai`.
- AWS console Name tag: `8byte-ai-vpc`, configurable through `vpc_name`.

Terraform identifiers cannot start with a digit, so the internal label is
`vpc_8byte_ai`. AWS Name tags can start with a digit. These are separate names;
references in subnet, routing, and output definitions use the Terraform label.
The rename was made before any infrastructure apply was run in this workflow.
The network creation plan was regenerated with the new label and tag before
the user applied it. Generate and review a fresh plan before any further apply.

## Routing

| Associated subnets | Route table | Configured internet route |
| --- | --- | --- |
| Public A and Public B | `aws_route_table.public` | `0.0.0.0/0` to the internet gateway. |
| Private A | `aws_route_table.private_a` | `0.0.0.0/0` to the NAT gateway. |
| Private B | `aws_route_table.private_b` | None. |

AWS automatically adds the VPC's local route to each route table. The more
specific local route handles traffic within `10.0.0.0/16`; the public default
route handles other IPv4 destinations. Security groups and network ACLs still
control which traffic is permitted.

Every subnet has an explicit association, rather than relying on the VPC's
main route table. Private A and B use separate tables so the NAT route
for the EC2 host in A does not automatically give B the same outbound route.
RDS may also reside in A, so subnet routing alone cannot distinguish EC2 from
RDS; security groups and keeping RDS non-public remain necessary.

Private A has an active default route to NAT, while private B has only its
local VPC route. No outbound service endpoint is configured. The SSH endpoint is a
management tunnel; it does not provide general internet access. Connectivity
testing still needs EC2.

## NAT outbound access — deployed

`nat.tf` defines an Elastic IP (`aws_eip.nat`) and one public, zonal NAT gateway
(`aws_nat_gateway.main`) in public subnet A. `routing.tf` defines
`aws_route.private_a_internet`, directing private A's `0.0.0.0/0` IPv4 traffic
to that gateway. The existing public route then reaches the internet gateway:

```text
EC2 in private A → NAT in public A → internet gateway → internet
```

NAT creation depends on the internet gateway, public internet route, and public-A
route-table association. Terraform uses resource references to create the EIP
before NAT and NAT before the private route. The VPC local route remains more
specific, so EC2-to-RDS traffic stays inside the VPC.

NAT handles connections initiated from the private subnet and their replies;
it does not make EC2 publicly addressable. EC2's security group permits outbound
TCP 80/443 for downloads and service APIs. NAT itself has no security group.
Private B receives no default route. RDS shares private A, so its separate
security group and non-public configuration remain essential.

One zonal gateway matches the single-EC2 assignment design. Keep EC2 in AZ A
to avoid cross-AZ NAT traffic; this does not provide outbound high availability
across AZs. Placement follows configurable subnet/AZ lists in `variables.tf`.

Budget for one gateway and one public IPv4 address: approximately $0.05/hour,
$3.60 for 72 hours, or $36.50 for 730 hours, before NAT data processing
($0.045/GB), applicable transfer charges, and taxes. NAT remains billable while
provisioned, even if EC2 is stopped; releasing an unused EIP is also necessary
to stop its address charges. The gateway and EIP are now provisioned and billable.

- [AWS NAT cost example for us-east-1](https://aws.amazon.com/blogs/networking-and-content-delivery/identify-and-optimize-public-ipv4-address-usage-on-aws/)
- [AWS VPC and public IPv4 pricing](https://aws.amazon.com/vpc/pricing/)
- [NAT gateway behavior](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)

## Security groups

| Connection | TCP port | Rule |
| --- | --- | --- |
| Internet → ALB | 80 | Inbound IPv4 HTTP from `0.0.0.0/0`. |
| ALB → EC2 staging | 8081 | ALB outbound and EC2 inbound reference the opposite security group. |
| ALB → EC2 production | 8082 | Same restriction, using the production host port. |
| EC2 → RDS | 5432 | EC2 outbound and RDS inbound reference the opposite security group. |
| SSH endpoint → EC2 | 22 | Endpoint outbound and EC2 inbound reference the opposite security group. |
| EC2 → web services | 80, 443 | Outbound only, for packages, container images, and service APIs through the deployed NAT route. |

`application_ports` configures the staging and production host ports. Later
container publication, ALB target groups, and health checks must use those same
values. Ports 22, 8081, 8082, and 5432 have no public inbound CIDR rule.

Rules use separate Terraform resources to avoid cycles between groups.
Terraform removes each newly created group's AWS default allow-all outbound
rule. RDS has no rule for initiating outbound connections; replies to permitted
connections are allowed because security groups are stateful. VPC DNS resolver
traffic is not filtered by security groups.

These groups do not enforce database user permissions or isolate staging from
production on the shared host. Attach the corresponding groups to EC2, RDS,
and ALB when those resources are implemented.

## SSH to private EC2

The EC2 Instance Connect Endpoint is placed in private subnet A, the planned
EC2 placement, to keep SSH traffic within one Availability Zone. It uses its
own security group and `preserve_client_ip = false`. The EC2 group permits SSH
from the endpoint group. The endpoint does not need an inbound rule: AWS
authenticates tunnel access through IAM.

AWS charges no additional fee for this endpoint. Connecting across Availability
Zones incurs data-transfer charges; keep the EC2 and endpoint placement aligned.
The endpoint needs no bastion host, EC2 public IP, or NAT gateway for SSH.
Regular EC2 and other infrastructure costs remain separate.

Creation requires the relevant EC2 permissions and permission to create the
service-linked role if it does not exist. Using the tunnel requires IAM
permission for `ec2-instance-connect:OpenTunnel`, plus SSH authentication.
The planned AL2023 standard AMI includes EC2 Instance Connect for temporary SSH
keys. Temporary-key use also needs `ec2-instance-connect:SendSSHPublicKey`.
No persistent SSH key is stored in Terraform. Opening tunnels and sending
temporary keys require caller
permissions. SSH connectivity can be tested only after EC2 exists.

Official references:

- [Endpoint operation and pricing](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-with-ec2-instance-connect-endpoint.html)
- [Endpoint security-group rules](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/eice-security-groups.html)

## Shared EC2 host — configured, not applied

| Setting | Configuration |
| --- | --- |
| Instance | `t3.medium`, 2 vCPUs and 4 GiB RAM, configurable through `ec2_instance_type`. |
| OS | Amazon Linux 2023 standard x86_64, pinned AMI `ami-0d27e0fb3bac4d724` in `us-east-1`. |
| Network | Private subnet A, existing EC2 security group, no public IP. |
| Disk | 30 GiB encrypted gp3, configurable through `ec2_root_volume_gb`. |
| Metadata | IMDSv2 required; hop limit 1; metadata tags disabled. |
| CPU credits | Standard mode, configurable through `ec2_cpu_credit_mode`. |
| Operator access | SSH through the existing endpoint, default OS user `ec2-user`, temporary keys. |
| Deployment access | SSH through the existing EC2 Instance Connect Endpoint; pipeline integration remains pending. |

The AMI was resolved from AWS's public AL2023 parameter during planning, then
pinned in `ec2_ami_id`. Terraform verifies Amazon ownership and x86 architecture.
Updating the AMI is a deliberate reviewed change and can replace the host.
Override the AMI when changing regions. Deploy images built for `linux/amd64`;
an ARM-only local image from an Apple Silicon Mac cannot run on this host.

The 4 GiB size is a starting point for two PetClinic environments plus Docker
and agents. Verify memory and CPU under representative load after deployment.
Standard mode avoids surplus CPU-credit charges, but sustained CPU use can
throttle once earned credits are exhausted. Builds belong in CI.

`scripts/bootstrap_ec2.sh` disables the bundled SSM Agent and installs Docker,
AWS CLI, jq, and EC2 Instance Connect from the OS package repository. It retries
package installation up to three times, enables Docker/SSH, and configures Docker json-file logs
with 10 MB files and three files per container. It uses no credentials or DB
passwords. EC2 creation depends on the NAT route.

Use `sudo docker` over SSH. The default user is not added to the docker group,
which would grant root-equivalent access. SSH deployment commands using sudo
have elevated host privileges; environment targeting needs a separate review.
Metadata hop limit 1 reduces access from bridge containers;
it is not complete isolation from a malicious or privileged container.

No EC2 IAM role or instance profile is configured in this stage. Registry,
secret, and monitoring access will need appropriate permissions in their later
reviewed steps. The pipeline's AWS identity and permissions for the SSH tunnel
and temporary keys are also pending. A GitHub-hosted runner cannot directly
SSH to the private IP over the internet; its deployment design must use the
existing endpoint. This choice does not expose port 22 publicly.

Environment Docker networks, PetClinic containers, database initialization,
and deployment workflows are application/deployment work. The bootstrap does
not start PetClinic or create RDS/ALB resources. Docker Compose is not installed
in this step; the current deployment design uses Docker CLI containers.

The encrypted root disk is deleted when the instance is terminated. Store
persistent application data in RDS and configure centralized logs in the
monitoring step. `user_data_replace_on_change = true` means bootstrap changes
trigger a reviewed instance replacement rather than an assumed script rerun.
Do not insert secrets into user data or Terraform variables/state.

Estimated incremental cost before taxes and transfer: $0.0418/hour for Linux
t3.medium, about $3.01 for 72 hours or $30.51 for 730 hours; 30 GiB baseline gp3
adds about $2.40/month. Budget roughly $3.25 for 72 hours or $32.91/month for
compute and disk combined. NAT and other services are additional. Stopping
EC2 does not stop disk or NAT charges.

After apply approval, verify instance status checks and encryption, wait for
cloud-init completion, inspect `/var/log/cloud-init-output.log`, confirm Docker
and SSH services, confirm SSM is disabled, test SSH through the endpoint,
and test an HTTPS download and a container image pull through NAT. Passing a
Terraform plan alone does not verify the bootstrap or connectivity.

Official references:

- [AL2023 AMI parameters](https://docs.aws.amazon.com/linux/al2023/ug/ec2.html)
- [SSH access on AL2023](https://docs.aws.amazon.com/linux/al2023/ug/connecting-to-instances.html)
- [T3 specifications, CPU credits, and pricing](https://aws.amazon.com/ec2/instance-types/t3/)
- [EBS pricing](https://aws.amazon.com/ebs/pricing/)
- [30 GiB gp3 cost example in us-east-1](https://aws.amazon.com/blogs/storage/migrate-your-amazon-ebs-volumes-from-gp2-to-gp3-and-save-up-to-20-on-costs/)

## State and credentials

- Existing bucket: `8byte.ai` in `us-east-1`.
- State object: `shared/terraform.tfstate`.
- Temporary lock object: `shared/terraform.tfstate.tflock`.
- Bucket versioning, default SSE-S3 encryption, and all four Block Public Access
  settings were verified before this configuration was written.
- The bucket is managed separately and is not created or destroyed by this configuration.
- Terraform uses the existing AWS credential chain. Do not put access keys in code.
- The backend region is the bucket's region. Changing `aws_region` does not move the state bucket.
- The AWS provider restricts resource operations to `aws_account_id`.

Native S3 locking prevents concurrent Terraform operations from modifying the
same state. This is separate from `.terraform.lock.hcl`, which pins provider
dependencies locally. The IAM principal needs bucket-list access, state-object
read/write access, and lock-object read/write/delete access. Successful
initialization does not by itself verify lock acquisition or state writes.

## Initialize and validate

Run these from the project root:

```sh
terraform -chdir=8Byte-Infra fmt -check
terraform -chdir=8Byte-Infra init -input=false
terraform -chdir=8Byte-Infra validate
```

Initialization connects to the existing backend and downloads the AWS provider.
Validation checks the Terraform configuration without creating resources.

Review a Terraform plan before approving an apply. No running application,
SSH connection, or end-to-end connectivity has been verified at this stage.

Generate the shared-host plan with:

```sh
terraform -chdir=8Byte-Infra plan -input=false -lock-timeout=30s -out=ec2.tfplan
```

Saved plans are local and excluded from version control by `.gitignore`.
The saved `network.tfplan`, `security.tfplan`, and `nat.tfplan` have been applied
and must not be reused.
`ec2.tfplan` is the reviewed, unapplied plan for the shared-host stage.
Generate a fresh plan if configuration or state changes. Applying requires
separate approval.

Official references:

- [S3 backend and native state locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [AWS VPC resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)
- [AWS subnet resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)
- [AWS internet gateway resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway)
- [AWS route table resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)
- [AWS route resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route)
- [AWS route table association resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association)

## Verification status

- `terraform fmt -check`: passed.
- `terraform init -input=false`: passed with the S3 backend and AWS provider 6.67.0.
- `terraform validate`: passed. The macOS sandbox prevented the provider plugin
  from starting locally; rerunning validation with the approved sandbox
  escalation succeeded without changing the configuration.
- The earlier VPC-only plan passed: one resource to add, no changes or deletions.
  S3 version metadata verified temporary lock creation and release.
- Formatting and validation for the four added subnets passed.
- The VPC-and-subnets plan passed: `5 to add, 0 to change, 0 to destroy`.
  All four CIDRs and Availability Zone placements match the layout above.
  The plan was saved locally as `network.tfplan`; Terraform reported releasing
  the state lock and exited successfully.
- Routing configuration passed formatting and validation.
- The updated saved plan passed: `14 to add, 0 to change, 0 to destroy`.
  It contains one VPC, four subnets, one internet gateway, three route tables,
  one public default route, and four subnet associations. The public route
  points to the internet gateway; no internet route is configured for either
  private table. Terraform released the state lock and exited successfully.
- The user subsequently applied the network foundation. Read-only verification
  found all 14 resource addresses in S3-backed state, VPC `vpc-0a31f18a7a2c900b0`
  named `8byte-ai-vpc`, four available subnets with the expected CIDRs and AZs,
  the attached internet gateway, active public routing, private local-only
  routing, and correct subnet associations. VPC DNS support and hostnames were enabled.
- The S3 state object was saved with AES256 encryption and a version ID;
  the current lock-object version was a delete marker, confirming lock release.
- The VPC label and AWS Name tag were subsequently changed to
  `aws_vpc.vpc_8byte_ai` and `8byte-ai-vpc`. Formatting and validation passed
  after this change. `network.tfplan` was regenerated and reviewed: the VPC
  address and Name tag match the new names, with `14 to add, 0 to change,
  0 to destroy`. Terraform released the S3 lock and exited successfully.
- The AWS provider block has now been moved to `providers.tf` within the same
  root module. Formatting and validation passed. A refreshed plan with
  `-detailed-exitcode` returned exit code 0 and reported: `No changes. Your
  infrastructure matches the configuration.` No apply was needed or run for
  the file reorganization.
- The security-group and SSH endpoint configuration passed formatting and
  validation. The refreshed plan saved as `security.tfplan` succeeded with
  `16 to add, 0 to change, 0 to destroy`: four groups, eleven standalone rules,
  and one endpoint. The endpoint targets private subnet A and disables client
  IP preservation. Existing network resources have no planned changes.
  Terraform released the state lock and exited successfully.
- After approval, `security.tfplan` was applied successfully: 16 added, zero
  changed, zero destroyed. AWS checks verified all eleven rules on the four
  groups, no public SSH or PostgreSQL ingress, no default allow-all egress,
  and no outbound rules on the RDS group. Endpoint `eice-056f2c3b79e0a9760`
  reached `create-complete` in private subnet A, `us-east-1a`, using the SSH
  endpoint group with client IP preservation disabled. A post-apply plan with
  `-detailed-exitcode` returned exit code 0 and reported no changes. SSH
  connectivity remains untested until EC2 and authentication are configured.
- NAT configuration passed `terraform fmt -check` and `terraform validate`.
  The refreshed `nat.tfplan` succeeded: `3 to add, 0 to change, 0 to destroy`.
  It places one public zonal NAT gateway in existing public A
  (`subnet-0498d6571a8830b05`), allocates one EIP, and adds the private-A default
  route to existing table `rtb-0c5036628be133cf9`. Existing network and security
  resources have no planned changes. Terraform released the S3 lock and exited
  successfully.
- After approval, `nat.tfplan` applied successfully: three added, zero changed,
  zero destroyed. AWS checks verified NAT `nat-0d5fac0f87ef06386` is `available`
  in public A, EIP allocation `eipalloc-093a6572ac18d288f` provides public IPv4
  `54.158.219.172`, private A has an active default route to NAT, private B
  remains local-only, and the public default route still points to the internet
  gateway. A post-apply plan with `-detailed-exitcode` returned exit code 0 and
  reported no changes; the state lock was released. Actual package/image
  downloads have not been tested because EC2 is not provisioned yet.
- The EC2 stage passed formatting, Terraform validation, and `bash -n` on
  the bootstrap script. AWS confirmed t3.medium has two vCPUs, 4096 MiB memory,
  and x86_64 architecture. Terraform verified the selected AMI is Amazon-owned
  and x86_64. After the user chose SSH-only administration and deployments,
  the SSM policy, instance role/profile, and their output were removed. The
  regenerated `ec2.tfplan` succeeded with `1 to add, 0 to change, 0 to destroy`:
  one instance. The plan confirms private A, no public IP, the existing EC2
  group, encrypted 30 GiB gp3, IMDSv2, and Standard CPU credits. Terraform
  released the lock. No apply, bootstrap run, or SSH test
  or PetClinic deployment has been performed for this stage.
