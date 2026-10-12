# Shared AWS infrastructure

Terraform provisions one shared EC2 host and one PostgreSQL RDS instance for
staging and production. Each application environment has its own container,
Docker network, database, credentials and ALB target group. The shared host and
Single-AZ database remain shared failure points; this is not a highly available
production platform.

The configuration follows HashiCorp's
[standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure):
a root composition layer, documented child modules with explicit inputs and
outputs, and tests for the complete stack.

## Current lifecycle

The latest cleanup was verified on 2026-10-11. The project infrastructure,
ALB log bucket, manually created S3 backend bucket and final RDS snapshot were
deleted. Eight application secrets remain scheduled for deletion. This is a
dated checkpoint, not a live inventory.

Start with the [project README](../README.md) for the complete setup order,
GitHub configuration, deployment steps, security decisions and cost measures.
This document covers the Terraform structure and its operating details.

This restructure changes local code organization only. It does not provision
AWS resources, change credentials, send notifications or deploy an application.
A fresh deployment needs a backend bucket, an unused secret suffix and an
unused final-snapshot identifier. Review an AWS plan before applying.
Historical implementation evidence is preserved in
[docs/implementation-history.md](docs/implementation-history.md).

## Folder structure

```text
8Byte-Infra/
├── backend.tf                 # S3 backend and native state locking
├── versions.tf                # Terraform/provider version constraints
├── providers.tf               # Region, permitted account and default tags
├── main.tf                    # Compose the shared stack from child modules
├── variables.tf               # Public inputs and deployment defaults
├── outputs.tf                 # Stable outputs for operators and pipelines
├── moved.tf                   # Previous root addresses mapped into modules
├── .terraform.lock.hcl        # Locked provider versions and checksums
├── environments/
│   └── shared.tfvars.example  # Example settings for the shared stack
├── modules/
│   ├── network/               # VPC, subnets, routes, NAT, SGs and SSH endpoint
│   ├── registry/              # ECR and image retention
│   ├── database/              # RDS and application secret containers
│   ├── logging/               # Log groups, collection config and log bucket
│   ├── compute/               # EC2, host IAM and bootstrap template
│   ├── load_balancer/         # ALB, listeners, targets and health checks
│   ├── pipeline/              # GitHub OIDC/IAM and SNS failure notifications
│   └── monitoring/            # Infrastructure/database and app dashboards
├── scripts/                   # Operator-only database setup and verification
├── tests/                     # Mocked integration contracts; no AWS access
└── docs/
    └── implementation-history.md
```

Each module contains `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and
its own README. Additional files organize larger components. The compute
bootstrap template is `modules/compute/templates/bootstrap_ec2.sh.tftpl`.

Use Terraform from `8Byte-Infra/`; do not initialize or apply the child modules
individually. Staging and production share infrastructure, so there is one
root and one state file. The `environments/` directory holds deployment input
files, not separate resource copies or separate staging/production stacks.
Creating physically separate environments would require an architectural
change and independent roots/state; a directory rename cannot provide isolation.

## Module responsibilities

| Module | Owns | Connects to |
| --- | --- | --- |
| [network](modules/network/README.md) | VPC, four subnets, routes, NAT, four security groups, SSH endpoint | Other modules consume its IDs |
| [registry](modules/registry/README.md) | Immutable ECR repository and image retention | Compute pull policy and pipeline push policy |
| [database](modules/database/README.md) | Private PostgreSQL RDS and two secret containers | Network, compute secret-read policy and operator initialization |
| [logging](modules/logging/README.md) | CloudWatch groups, host/Docker collection config and ALB log bucket | Compute bootstrap and ALB log delivery |
| [compute](modules/compute/README.md) | Shared EC2 and its scoped role/profile | Network, registry, database and logging |
| [load_balancer](modules/load_balancer/README.md) | ALB, environment listeners/target groups and health checks | Network, compute and logging |
| [pipeline](modules/pipeline/README.md) | GitHub OIDC roles, deployment permissions and SNS | Registry, compute and SSH endpoint |
| [monitoring](modules/monitoring/README.md) | Two CloudWatch dashboards | Instance/database identifiers, ALB dimensions and host namespace |

Provider blocks stay at the root. Child modules declare provider requirements
and inherit the configured AWS provider. The root enforces the expected AWS
account and adds `Project` and `ManagedBy` tags. Module references connect IDs,
ARNs and collection settings. Dependencies on specific module outputs ensure
network routing precedes bootstrap and log delivery configuration precedes
ALB creation. This avoids broad dependencies that would also delay unrelated
data lookups, such as selecting the pinned AMI.

## Configure the shared deployment

From the repository root:

```bash
cp 8Byte-Infra/environments/shared.tfvars.example 8Byte-Infra/environments/shared.tfvars
```

Review that file before planning. Actual `.tfvars` files are ignored by Git;
only example files are committed. No passwords or AWS access keys belong in
these files. Root defaults remain compatible with the previous configuration.

Choose an unused `database_secret_suffix` when prior names are reserved during
Secrets Manager deletion recovery. Keep that suffix unchanged for the lifetime
of the deployment. Set the GitHub Actions repository variable
`DATABASE_SECRET_SUFFIX` to the same value. The initializer and instance policy
consume generated secret ARNs; the deployment scripts use the matching suffix.

Use a unique `rds_final_snapshot_identifier` when a retained final snapshot
already uses the previous name. Reconfirm SNS email subscriptions after a fresh
creation. Verify the pinned AMI, Availability Zones and RDS engine/class when
changing region or deliberately upgrading.

## Backend and Terraform commands

`backend.tf` uses S3 bucket `8byte.ai`, key `shared/terraform.tfstate`, region
`us-east-1`, encryption and native locking with `use_lockfile = true`. The bucket
is manually bootstrapped and is not managed by this stack. Before initializing,
create or restore a bucket under your account with versioning, server-side
encryption and public-access blocking. If that name is unavailable or a new
bucket is chosen, update the backend configuration before initialization.
Backend settings cannot use regular Terraform input variables.

The project README shows how to create an account-specific bucket and pass its
name through `-backend-config`. When using that approach, keep the same override
on later initialization commands so Terraform continues using the same state.

After the backend is ready, run from the repository root:

```bash
terraform -chdir=8Byte-Infra init -reconfigure -backend-config="bucket=$task_state_bucket"
terraform -chdir=8Byte-Infra fmt -check -recursive
terraform -chdir=8Byte-Infra validate
terraform -chdir=8Byte-Infra plan -var-file=environments/shared.tfvars -out=reviewed.tfplan
```

Set `task_state_bucket` to your existing backend bucket name before the commands
above, or use the value from the project README's bootstrap step. Inspect the
plan, including additions, updates, replacements and deletions.
Apply a freshly reviewed plan only after approval:

```bash
terraform -chdir=8Byte-Infra apply reviewed.tfplan
terraform -chdir=8Byte-Infra output
```

Keep `.terraform.lock.hcl` committed for repeatable provider installation.
Downloaded providers, local state, saved plans, private keys and actual variable
files stay ignored. Do not reuse saved plans after an apply or configuration
change. S3 holds current state after successful Terraform state changes and
retains older versions when bucket versioning is enabled.

## Local validation without the S3 backend

When the backend has been deleted, use an isolated Terraform data directory
so old cached backend settings do not interfere with local checks:

```bash
task_tf_data_dir="$(mktemp -d)"
TF_DATA_DIR="$task_tf_data_dir" terraform -chdir=8Byte-Infra init -backend=false
TF_DATA_DIR="$task_tf_data_dir" terraform -chdir=8Byte-Infra validate
TF_DATA_DIR="$task_tf_data_dir" terraform -chdir=8Byte-Infra test
terraform -chdir=8Byte-Infra fmt -check -recursive
```

The tests use a mocked AWS provider and plan operations. They verify the host
collector namespace, rendered bootstrap, dashboard dimensions, container/system
log wiring, scoped log permissions and access-log bucket protections. They do
not prove AWS connectivity, live dashboards or application health.

## Database initialization and deployment

Root output names are unchanged, so the existing operator command still works:

```bash
python3 8Byte-Infra/scripts/initialize_databases.py --execute
```

Run this explicitly after infrastructure creation, with local AWS access and
the new host's verified SSH public key registered in `~/.ssh/known_hosts`. It
installs a PostgreSQL client if necessary, generates separate application
passwords, writes Secrets Manager values outside Terraform, creates restricted
database users/databases and checks own-database access, cross-database denial
and persistence. Neither the admin nor application password is stored in
Terraform configuration or state.

After recreation, update the GitHub Actions variables from the root outputs:
EC2 instance ID, verified SSH host key, staging/production URLs, ECR URL/name,
AWS deployment/notification role ARNs, SNS topic ARN, region and the chosen
secret suffix. The workflow uses SSH through EC2 Instance Connect Endpoint;
no SSM deployment access is configured. Application changes on `main` trigger
build, scans and staging deployment. Production is manually promoted from a
successful staging workflow run using the same image digest.

## Address migration

Moving a resource into a child module changes its Terraform address. For
example, `aws_instance.application` becomes
`module.compute.aws_instance.application`. `moved.tf` records all 66 managed
resource blocks and the AMI data source so Terraform can map retained older
state to these addresses. This uses HashiCorp's
[module refactoring mechanism](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring).

Keep the same backend/key when migrating an existing deployment and retain
these mappings. Do not combine this reorganization with an AWS resource rename
or an unrelated configuration change. A refreshed AWS plan remains required to
confirm migration-only changes for any live deployment. If state is empty,
Terraform plans a fresh creation; a moved block does not recover deleted state.
This repository's backend was deleted during cleanup, so no live migration
plan was run for this restructure.

## Security, monitoring and cleanup

EC2 and RDS have no public access. Security-group references enforce ALB to EC2
on host ports 8081/8082, EC2 to PostgreSQL on 5432, and SSH endpoint to EC2 on 22.
Public ALB listeners are production 80 and staging 8081; public Actuator paths
are blocked. HTTP and optional PostgreSQL TLS remain the reviewed assignment
choices. Docker bridge networks and separate credentials give logical
separation, not complete tenant isolation or application high availability.

RDS storage is encrypted, backups are retained for seven days, and deletion
protection/final snapshots are enabled. ECR tags are immutable, images are
scanned on push and the newest 30 are retained by default. Logs have bounded
retention; host metric/log writes and image/secret access are scoped. Both
CloudWatch dashboards require live collectors and application traffic to
populate. ALB metrics describe traffic through the load balancer.

Cleanup requires a reviewed destroy plan. Nonempty ECR/log buckets and RDS
deletion protection intentionally prevent blind deletion. Review image/log
removal and any protection changes explicitly. Retained RDS snapshots can
continue to incur storage charges; application secrets retain their reserved
names during the configured recovery window. Delete the S3 state bucket last,
after confirming state and project resources are cleared.
