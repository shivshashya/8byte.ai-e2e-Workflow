locals {
  application_databases = {
    staging = {
      dbname   = "app_staging"
      username = "staging_user"
    }
    production = {
      dbname   = "app_production"
      username = "production_user"
    }
  }
}

# Terraform manages secret containers only. The initialization step writes
# generated credentials through Secrets Manager, never through Terraform state.
resource "aws_secretsmanager_secret" "database" {
  for_each = local.application_databases

  name                    = "${var.project_name}/${each.key}/database${var.database_secret_suffix == "" ? "" : "-${var.database_secret_suffix}"}"
  description             = "PetClinic ${each.key} PostgreSQL connection credentials"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-${each.key}-database"
    Environment = each.key
  }
}

resource "aws_iam_role_policy" "application_database_secrets" {
  name = "petclinic-database-secrets-read"
  role = aws_iam_role.application.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadApplicationDatabaseCredentials"
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = [for secret in aws_secretsmanager_secret.database : secret.arn]
    }]
  })
}
