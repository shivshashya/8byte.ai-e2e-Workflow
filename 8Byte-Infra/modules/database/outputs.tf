output "rds_instance_id" {
  description = "RDS provider resource ID."
  value       = aws_db_instance.application.id
}

output "rds_identifier" {
  description = "RDS database identifier for metrics."
  value       = aws_db_instance.application.identifier
}

output "rds_address" {
  description = "Private PostgreSQL endpoint."
  value       = aws_db_instance.application.address
}

output "rds_port" {
  description = "PostgreSQL TCP port."
  value       = aws_db_instance.application.port
}

output "rds_admin_secret_arn" {
  description = "RDS-managed admin secret ARN; never the password."
  value       = aws_db_instance.application.master_user_secret[0].secret_arn
}

output "database_secret_arns" {
  description = "Application database secret ARNs by environment."
  value       = { for environment, secret in aws_secretsmanager_secret.database : environment => secret.arn }
}
