# Infrastructure: networking and shared application host

This configuration defines the shared VPC, four subnets, an internet gateway,
route tables, four security groups, and an EC2 Instance Connect Endpoint for
SSH. The user applied the network foundation; read-only AWS checks verified
the resources and routing afterward. The reviewed security groups and SSH
endpoint have also been applied and verified in AWS. The NAT gateway, its
Elastic IP, and private-A default route have also been applied and verified.
The user approved the corrected SSH-only EC2 replacement. Cloud-init, SSH,
Docker, outbound HTTPS, and a Docker Hub image pull/container run passed.
Private RDS, ECR, pipeline IAM/SNS and application database credentials have
also been applied and verified; see their checkpoints below. The reviewed ALB
plan has been applied and live listener/security checks passed. Staging serves
the PetClinic homepage with HTTP 200; production readiness and the complete
automated deployment/promotion flow remain pending.

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
| `alb.tf` | Public ALB, separate environment listeners/target groups, EC2 attachments and management-path blocking. |
| `rds.tf` | Define the private Single-AZ PostgreSQL instance, subnet group and optional-TLS parameter group. |
| `ecr.tf` | Shared immutable PetClinic image repository, push scanning and image retention. |
| `iam.tf` | GitHub OIDC deployment/notification roles and EC2 pull-only role/instance profile. |
| `sns.tf` | Pipeline failure topic and owner-confirmed email subscription. |
| `secrets.tf` | Application secret containers and scoped EC2 secret-read policy. |
| `scripts/initialize_databases.sql` | PostgreSQL roles, databases and grants; initialization completed and verified. |
| `scripts/initialize_databases.py` | Operator-only credential generation/storage, SSH setup and initialization orchestration. |
| `scripts/database_host.py` | Internal EC2-side SQL executor and database connectivity/isolation checks. |
| `scripts/bootstrap_ec2.sh` | First-boot installation of Docker and deployment tools, service startup, and local log rotation. |
| `variables.tf` | Define configurable region, account, names, CIDRs, Availability Zones, and staging/production host ports. |
| `outputs.tf` | Expose infrastructure IDs, pipeline role/topic ARNs, secret ARNs, ALB URLs and target-group ARNs. |
| `.terraform.lock.hcl` | Generated during initialization; records the selected provider version and checksums. Commit this file. |

All top-level `.tf` files in `8Byte-Infra/` form one Terraform root module.
File names organize the code for readers; resource references determine
dependencies. Moving the provider block between files in the same directory
does not change resource addresses or AWS settings. Keep this single root
module for the shared infrastructure; reusable child modules are optional later.

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

## Shared EC2 host — applied and verified

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

The pipeline configuration now defines an EC2 IAM role and instance profile
with ECR pull access; attachment is pending approval of `pipeline.tfplan`.
Secret and monitoring access require permissions in their later reviewed steps. The pipeline's AWS identity and permissions for the SSH tunnel
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

Verification on 2026-10-09: the original instance failed bootstrap because the
script requested nonexistent AL2023 package `awscli2`. After correcting it to
`awscli-2`, the user approved `ec2-bootstrap-fix.tfplan`; apply replaced EC2
(one added, zero changed, one destroyed). Both applied EC2 plans are stale and
must not be reused.

Replacement instance `i-0098d269cbcde9de6` is running at `10.0.10.213`.
Both EC2 health checks passed. It has no public IP or instance profile;
the 30 GiB gp3 root disk is encrypted, IMDSv2 is required with hop limit 1,
and CPU credits use Standard mode. SSH through the endpoint worked.
Cloud-init returned `status: done` and logged `EC2 host bootstrap completed.`
Docker and SSH are active; SSM is disabled and inactive. Docker log rotation
matches the source configuration. HTTPS returned HTTP 200, and
`sudo docker run --rm hello-world` pulled the amd64 Docker Hub image and
successfully ran it through NAT. The test container was automatically removed.
A post-apply Terraform plan returned exit code 0 with no changes.
PetClinic deployment and its runtime/resource/isolation checks remain pending.

Connect using the current instance ID:

```bash
aws ec2-instance-connect ssh \
  --region us-east-1 \
  --instance-id i-0098d269cbcde9de6 \
  --os-user ec2-user \
  --connection-type eice \
  --eice-options endpointId=eice-056f2c3b79e0a9760,maxTunnelDuration=300
```

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

## PostgreSQL RDS — configured, not applied

The reviewed configuration uses PostgreSQL 18.4 on `db.t3.small` (2 vCPUs,
2 GiB RAM), 20 GiB encrypted gp3 and Single-AZ placement in private A.
The subnet group includes both private subnets. The existing RDS security group
allows TCP 5432 only from the application EC2 security group. Public access is
disabled. AWS orderable-instance checks confirmed this version/class is offered
in our AZs; the checked T4g small combinations were listed only in us-east-1f.

The user chose optional TLS. PostgreSQL 18 defaults to requiring TLS, so a
custom `postgres18` parameter group sets `rds.force_ssl = 0` through
`rds_require_tls = false`. TLS remains available, and unencrypted connections
are permitted. A future parameter change uses pending-reboot application;
review and reboot deliberately after changing it.

RDS generates the `db_admin` password and stores it in Secrets Manager using
`manage_master_user_password = true`. Terraform exposes only the secret ARN
and never retrieves its password. No password belongs in variables, outputs,
plans, logs or chat. This stage creates only the RDS-managed admin secret.
The application databases `app_staging` and `app_production`, restricted users,
and their two separate secrets require post-provision initialization. Do not
run application containers with the admin account. Secret retrieval and
pipeline permissions remain to be reviewed; SSH-only does not require SSM.

Automated backups retain seven days, with a 01:00–01:30 UTC backup window and
Sunday 02:00–03:00 UTC maintenance window. Automatic minor upgrades are enabled;
major upgrades are not. Future changes use the maintenance window rather than
`apply_immediately`. Capacity is fixed at 20 GiB unless deliberately resized;
storage autoscaling is not enabled. Application load and connection counts
must be measured after deployment. Shared DB capacity and failures affect both
environments; Single-AZ provides no standby failover.

Deletion protection is enabled. Cleanup requires a reviewed apply to disable
it, then a separately approved deletion. A final snapshot is required and
retained; its default name is `petclinic-<project_name>-final`. Override
`rds_final_snapshot_identifier` if that snapshot already exists. Retained
snapshots and secrets can continue incurring charges after cleanup.

Verified public AWS us-east-1 list prices: compute $0.036/hour ($26.28 per
730 hours); 20 GiB gp3 $2.30/month; Secrets Manager $0.40/secret/month plus
API calls. This stage's one secret gives a baseline of $28.98/month or roughly
$2.86/72 hours. Including the two later application secrets gives $29.78/month
or roughly $2.94/72 hours. Taxes, transfer, excess backup storage and surplus
CPU credits are additional. RDS T3 runs in Unlimited mode, unlike our EC2's
Standard credits. Existing EC2, NAT and future ALB costs are separate.

After an approved apply, verify RDS availability, private network placement,
storage encryption, backup retention and applied parameter settings. Connect
from EC2, verify non-TLS connectivity is allowed and confirm restricted-user
cross-database access is rejected after database initialization. These runtime
checks have not yet run.

References:

- [AWS PostgreSQL TLS behavior](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html)
- [RDS-managed admin passwords](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)
- [AWS us-east-1 RDS price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRDS/current/us-east-1/index.json)
- [RDS pricing and CPU credits](https://aws.amazon.com/rds/postgresql/pricing/)
- [Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/)

Configuration checks passed: `terraform fmt -check` and `terraform validate`.
Saved review plan `rds.tfplan` contains **3 additions, 0 changes, 0 destructions**:
RDS instance, DB subnet group and DB parameter group. It has not been applied.
The managed admin secret is created by RDS, not a separate Terraform resource.

## Pipeline infrastructure — configured, not applied

`ecr.tf` creates one private `8byte-petclinic` repository for both environments,
with immutable tags, AES256 encryption and scan on push. The lifecycle policy
retains the newest 30 images (`ecr_retained_image_count`) and expires older
images, including tagged images. ECR does not know which images are deployed;
ensure a required rollback image remains inside the retention window. Use
unique build tags and promote the same digest, rather than overwriting staging,
production or latest tags. Repository deletion requires explicitly emptying it;
`force_delete` is false. Scan on push does not itself reject vulnerable images;
the CI scan gate remains application/pipeline work.

AWS IAM currently has no OIDC provider in this account, so `iam.tf` creates
`https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
The deployment role trusts only this exact subject:

```
repo:shivshashya@109200716/8byte.ai-e2e-Workflow@1410967056:ref:refs/heads/main
```

No GitHub environment subject or wildcard is allowed. Workflow jobs need
`permissions: id-token: write` and normally `contents: read`. Jobs using GitHub
environments or pull-request OIDC subjects cannot assume this role. Production
approval logic remains in the workflow design.

The GitHub role permits ECR login (the API requires Resource `*`), repository-
scoped push/pull, OpenTunnel only on the existing endpoint with destination
port 22 and the application's private IP, SendSSHPublicKey only on the
application instance for `ec2-user`, and the two requested EC2 discovery APIs
(which require Resource `*`). The private-IP/instance references follow future
Terraform replacements. No permanent AWS keys are needed in GitHub.

The EC2 role trusts the EC2 service and grants ECR login plus pull-only access
to this repository. Its instance profile attaches to the existing host in
place. Host AWS CLI commands can use instance credentials for Docker login.
The IMDSv2 hop limit remains 1. No SSM permissions or admin secret access are
added. Read access to the two application DB secrets remains pending their
creation and review; the shared role will eventually access both environments.

Outputs for pipeline configuration:

| Terraform output | Pipeline use |
| --- | --- |
| `ecr_repository_url` | Full registry/repository image path |
| `github_actions_role_arn` | OIDC role-to-assume |
| `ec2_instance_id` | SSH public-key target |
| `ssh_endpoint_id` | EIC tunnel endpoint |

Formatting and validation passed. `pipeline.tfplan` shows **8 additions,
1 in-place update, 0 destructions**. The additions are ECR repository/lifecycle,
OIDC provider, GitHub role/policy and EC2 role/policy/profile; the update attaches
the instance profile. No pipeline infrastructure apply has occurred. Runtime
OIDC authentication, repository push/pull and deployment-role SSH remain untested.
After approved apply, verify trust/policies and profile attachment, then test
host ECR login/pull and main-branch GitHub OIDC push/SSH through the pipeline.

The refreshed plan also found RDS already applied. AWS reports it available,
PostgreSQL 18.4 on db.t3.small in us-east-1a, private and encrypted, with seven-day
backups and its parameter group in-sync. No RDS resource changes appear in the
pipeline plan. Database connection and restricted-user checks remain pending.
This checkpoint supersedes the earlier README notes that RDS was not applied;
do not reuse the earlier RDS plan.

ECR storage is approximately $0.10/GB-month (e.g. 5 GB is $0.50/month), with
additional applicable transfer and existing NAT processing charges. The
repository's basic scan-on-push setting is used. IAM resources have no separate
hourly compute cost. RDS/EC2/NAT costs remain separate.

References:

- [ECR pricing](https://aws.amazon.com/ecr/pricing/)
- [EIC endpoint IAM conditions](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/permissions-for-ec2-instance-connect-endpoint.html)
- [ECR push permissions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push-iam.html)
- [IAM OIDC provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

## Pipeline failure notifications — configured, not applied

`sns.tf` defines the standard topic `8byte-devops-pipeline-failures` in the
provider region us-east-1 and an email subscription to shivshashyadev@gmail.com.
The address is configurable through `pipeline_alert_email`. AWS sends a
confirmation email on subscription creation; the owner must click its Confirm
subscription link. Terraform creating the subscription does not prove delivery
is active. No confirmation email or test alert has been sent in this step.

`iam.tf` defines a second GitHub role `8byte-devops-github-notifications`, using
the same OIDC provider with audience sts.amazonaws.com. Its exact allowed
subjects are:

```
repo:shivshashya@109200716/8byte.ai-e2e-Workflow@1410967056:ref:refs/heads/main
repo:shivshashya@109200716/8byte.ai-e2e-Workflow@1410967056:pull_request
```

Its sole permissions policy grants `sns:Publish` on the failure topic ARN only.
It grants no repository push/pull, SSH or secret access. The main-only deployment
role's trust remains unchanged. Notification workflow jobs need id-token: write
and must assume this separate role; workflow integration is handled in the pipeline work.

Outputs: `pipeline_failure_topic_arn` and `github_notifications_role_arn`.
The workflow should include the repository/run URL and failed job in a plain
text alert, keeping passwords/tokens out of messages.

Formatting and validation passed. Saved `notifications.tfplan` includes the
pending pipeline infrastructure and notifications: **12 additions, 1 in-place
EC2 profile attachment, 0 deletions**. Four additions are the topic, subscription,
notification role and its policy; eight are the previous ECR/IAM resources.
Nothing in this plan has been applied. Use this expanded review plan rather
than the earlier pipeline plan. After approved apply and owner confirmation,
verify the role policies/trust and confirmed subscription, then test delivery
through the failure workflow. Authentication and delivery remain unverified.

SNS standard requests cost $0.50 per million requests and email deliveries
$2.00 per 100,000 deliveries beyond applicable free allowances. Ordinary small
failure-alert volumes therefore have very small usage charges; taxes and any
other applicable charges are additional. Existing ECR/RDS/EC2/NAT costs remain
separate.

References:

- [AWS email subscription confirmation](https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html)
- [SNS pricing](https://aws.amazon.com/sns/pricing/)
- [SNS pricing FAQ](https://aws.amazon.com/sns/faqs/)

## Application database setup — configuration prepared, initialization pending

`secrets.tf` creates secret containers `8byte-devops/staging/database` and
`8byte-devops/production/database` with seven-day deletion recovery. No secret
versions or password values are managed by Terraform. EC2 receives only
GetSecretValue on these two secret ARNs, using AWS-managed secret encryption;
no admin-secret access is added. The shared host role can read both environments.
Output `database_secret_arns` maps staging and production to their secret ARNs.

The post-apply initialization step must generate different random passwords
and store connection JSON in each matching secret outside Terraform:
`engine`, `host`, `port`, `dbname`, `username`, `password`.
Staging uses app_staging/staging_user; production uses
app_production/production_user. Map host/port/dbname into POSTGRES_URL and use
username/password as POSTGRES_USER/POSTGRES_PASS. No resolved credentials belong
in version control, terminal output, command arguments or Terraform state.
Secrets remain empty until their values are explicitly populated.

`initialize_databases.sql` creates missing login roles and owned databases,
rejects unexpected existing database owners, revokes PUBLIC database access and
cross-environment grants, and removes PUBLIC schema permissions. Application
users own their databases because PetClinic initializes tables on startup; this
is database-scoped access, not read/write-only permissions. Existing passwords
and data are preserved; rerunning requires the matching existing secret values.
The administrator is granted role membership to create/manage owned databases.
Credential input/execution must use protected stdin and a PostgreSQL client;
this SQL file alone is not a credential-generation or deployment runner.

Live network check from EC2 i-0098d269cbcde9de6 succeeded: RDS DNS resolved to
10.0.10.8 and TCP 5432 accepted a connection. This does not verify PostgreSQL
authentication. No psql executable is currently installed on EC2. Installing a
client, secure credential initialization and authenticated verification follow
the reviewed secret-resource apply. Required checks: both users can connect to
their own DB, both cross-DB connections are rejected, non-TLS connectivity is
allowed as requested, and data persists across separate connections.

Formatting and validation passed. Saved database-secrets.tfplan has **3 adds,
0 changes, 0 destructions**: two secret containers and one read policy. It has
not been applied. Secret values, application users/databases, PetClinic/RDS
runtime integration and ALB remain pending. Two secrets add approximately
$0.80/month plus API calls, within the previously discussed three-secret total.

Latest application handoff reports a GitHub OIDC subject mismatch blocking
image pushes: the repository uses an immutable subject prefix, while the roles
currently trust the original name-based prefix. No trust-policy correction was
made in this database step; verify and review that change separately before
claiming the deployment pipeline works.

## GitHub immutable OIDC trust correction — prepared, not applied

Live `gh api repos/shivshashya/8byte.ai-e2e-Workflow/actions/oidc/customization/sub`
returned use_immutable_subject=true and the exact supplied prefix. The source
now builds that prefix from github_repository, github_owner_id (109200716) and
github_repository_id (1410967056). Deployment trust allows only main;
notification trust allows main and pull_request. Both retain audience
sts.amazonaws.com and the same OIDC provider. Permissions policies are unchanged.

Formatting and validation passed. Saved oidc-database.tfplan includes the
pending secret containers/read policy and the two in-place trust corrections:
**3 additions, 2 changes, 0 deletions**. It has not been applied. Do not use the
older database-secrets.tfplan if expecting the OIDC fix; it omits this correction.
After approved apply, verify both AWS trust policies and rerun the failed
workflow to prove role assumption and image push. No workflow rerun was made
in this configuration step. This supersedes the earlier note that no OIDC
source correction was prepared; live AWS still needs the reviewed apply.

## OIDC/database-secret apply verification — 2026-10-09

The reviewed plan oidc-database.tfplan was applied: 3 added, 2 changed,
0 destroyed. AWS confirmed both immutable GitHub subjects and audience,
two application secret containers, and EC2 GetSecretValue scoped to those
secret ARNs. Deployment trust remains main-only; notification trust permits
main/pull_request. Both application secrets currently have no versions/values.
Post-apply Terraform plan exited 0 with no changes. Do not reuse the applied
plan. GitHub workflow rerun/OIDC authentication, credential population,
PostgreSQL users/databases and isolation checks remain pending. ALB remains
pending. This checkpoint supersedes earlier not-applied notes for this step.

## Application database initialization — completed and verified, 2026-10-09

The user approved credential generation, database initialization and access
checks. `scripts/initialize_databases.py --execute` completed through SSH to
private EC2. PostgreSQL 17 client was installed on the host; RDS remains
PostgreSQL 18.4. Operator AWS credentials retrieved the RDS-managed admin secret;
EC2's IAM policy still permits only the two application secrets. Admin values
were passed through noninteractive SSH stdin and a temporary protected pgpass
file, not command arguments or Terraform. Temporary credential/key files were
removed. Generated application passwords are different 64-character random
hex strings (256-bit entropy). They are stored as AWSCURRENT versions outside
Terraform with the documented engine/host/port/dbname/username/password contract.

| Environment | Database | User | Secret name |
| --- | --- | --- | --- |
| staging | app_staging | staging_user | 8byte-devops/staging/database |
| production | app_production | production_user | 8byte-devops/production/database |

The prepared SQL created the databases/users, with each app user owning only
its matching application database, no superuser/create-role/create-database/
replication/bypass-RLS privileges and no inherited role memberships. PUBLIC
and cross-environment database grants were revoked; PUBLIC schema access was
removed. The admin retains membership to manage these owned databases.

Runtime checks passed for both environments: own database login, cross-database
connection rejected specifically for CONNECT permission, non-TLS connectivity,
and persistence of an inserted row across separate connections. Unique test
tables were dropped afterward. The host used its instance role to retrieve both
stored application credentials successfully. A second initializer run passed
without changing either secret version; existing credentials were reused.
The post-operation Terraform plan exited 0 with no changes.

To rerun explicitly as an authorized operator (not a deployment job):

```bash
python3 8Byte-Infra/scripts/initialize_databases.py --execute
```

The runner reads current Terraform outputs, validates the AWS account, uses
previously trusted SSH host keys, generates temporary SSH keys, and preflights
existing owners/privileges and statement logging. It preserves existing secret
values and passwords and writes any missing secret values before SQL, enabling
recovery after a partial run. It aborts on unexpected owners, privileged app
roles, app role memberships, or an existing role without recorded credentials.
`database_host.py` is an internal helper consumed over SSH; it must not receive
resolved credentials via command arguments or terminal-pasted JSON.

This proves database/client connectivity and database-level permission
isolation. PetClinic containers have not yet been connected to these RDS
credentials, so app startup/restart persistence and host container isolation
remain pending. Shared EC2 IAM can read both secrets; database isolation does
not isolate privileged host operators or applications with host credentials.
The ALB has since been applied and verified below. This checkpoint supersedes earlier
notes that the application secrets were empty and databases uninitialized.

## ALB apply and verification — 2026-10-09

Formatting and Terraform validation passed. The user approved applying
`alb.tfplan`: **10 additions, 0 changes, 0 deletions**: one ALB, two target groups, two registrations,
two listeners, two management-path rules and one staging ALB ingress rule.
Existing EC2/RDS/IAM resources are unchanged. AWS confirmed both public subnets
have sufficient free IPs and no existing ALB was present. Reviewed plan values
match the selected ports, current EC2 instance and HTTP 200 health matcher.
The apply completed successfully. Live AWS checks confirmed active status,
intended public subnets/security group, listener-to-target-group mappings,
current EC2 registrations and malformed-header/deletion-protection settings.
The post-apply plan exited 0 with no changes. The applied plan is ignored by
Git and must not be reused; generate a fresh plan for future changes.

One internet-facing IPv4 Application Load Balancer spans public A and public B
using the existing ALB security group. The user selected separate public HTTP
ports because no domain is available yet. This replaces the HLD's proposed
domain-based host routing and avoids application context-path changes.

| Environment | Public URL after apply | EC2 target port |
| --- | --- | --- |
| Production | `http://<ALB-DNS>` | 8082 |
| Staging | `http://<ALB-DNS>:8081` | 8081 |

Actual DNS: `8byte-devops-alb-256496465.us-east-1.elb.amazonaws.com`.
The staging target is healthy and its public `/` returned HTTP 200 with the
PetClinic page title. The production target failed health checks
(`Target.FailedHealthChecks`) and its public `/` returned HTTP 502; application
readiness remains pending. Both listeners returned HTTP 404 for `/actuator`,
`/actuator/health` and `/actuator/env`. These checks prove the ALB entry points
and staging page availability, not the full pipeline or database persistence
through an application restart.

`alb_listener_ports` configures the public ports; `application_ports` configures
the EC2 ports independently. The existing production ALB ingress remains TCP
80. One new ingress rule admits public TCP 8081 to the ALB; EC2 continues to
accept application traffic only from the ALB security group. No public EC2 IP,
SSH ingress or PostgreSQL ingress is added.

Each environment has an HTTP listener, target group and registration of the
same EC2 instance at its own application port. Health checks call
`/actuator/health` directly on the target port, require HTTP 200, run every
30 seconds with a 5-second timeout and use thresholds of two successes/failures.
`alb_health_check_path` is configurable. Health-check success and application
startup are runtime checks after deployment, not results of Terraform validation.

Each listener returns a fixed 404 for `/actuator` and `/actuator/*`, keeping
management endpoints off the public entry points. The app currently exposes
all Actuator endpoints in its development configuration; production deployment
should restrict exposure with `MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health`
and keep health details private. ALB health checks bypass listener rules.
Malformed HTTP header fields are dropped. Access logs and monitoring dashboards
remain for the monitoring milestone. HTTPS/domain configuration is optional
later work. Deletion protection defaults to false for assignment cleanup and
can be changed with `alb_deletion_protection`.

Both target groups share one host; this does not provide application HA or
zero-downtime container replacement. ALB can route to unhealthy targets when
all registered targets are unhealthy (fail-open); deployment jobs must explicitly
check readiness and fail/roll back on failed checks.

Outputs `application_urls`, `alb_dns_name`, `alb_arn` and
`alb_target_group_arns` provide the public addresses and verification targets.
Initial checks can run over SSH on EC2 using `http://127.0.0.1:8081/actuator/health`
and `http://127.0.0.1:8082/actuator/health`. Public app checks should use `/`,
while public Actuator paths should return 404. The pipeline deployment role has
not been granted ELB API permissions; use SSH-local checks or request scoped
permissions if pipeline target-health API polling is needed.

Incremental estimate in us-east-1: $0.0225/ALB-hour plus $0.008/LCU-hour and
$0.005/public-IPv4-hour. Assuming two ALB IPv4 addresses, the hourly baseline
is $0.0325, about $2.34 for 72 hours or $23.73 for 730 hours, before LCU usage,
transfer, taxes and any additional addresses. This excludes existing EC2,
NAT, RDS and other costs. Rates checked against
[AWS ELB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/) and
[AWS public IPv4 pricing](https://aws.amazon.com/vpc/pricing/).
See [AWS health-check behavior](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)
for the fail-open limitation.

The S3 backend saved the updated state at `s3://8byte.ai/shared/terraform.tfstate`.
Post-apply metadata confirmed a version ID and AES256 encryption; the temporary
`shared/terraform.tfstate.tflock` object was absent after lock release. Terraform
handles state writes through the configured backend automatically. Versioning
retains prior state object versions; multiple writes can occur during an apply.
An ordinary plan reads/refreshes state for comparison and does not apply changes
or persist refreshed resource values as an apply does.
