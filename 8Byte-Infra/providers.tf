provider "aws" {
  region = var.aws_region

  # Prevent accidentally provisioning into a different AWS account.
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}
