output "vpc_id" {
  description = "ID of the shared application VPC."
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "IPv4 CIDR range of the shared application VPC."
  value       = module.network.vpc_cidr
}

output "ssh_endpoint_id" {
  description = "EC2 Instance Connect Endpoint ID for SSH to the planned private EC2 host."
  value       = module.network.ssh_endpoint_id
}

output "ec2_instance_id" {
  description = "Shared application instance ID for SSH access and deployment targeting."
  value       = module.compute.ec2_instance_id
}

output "ec2_private_ip" {
  description = "Private IPv4 address of the shared application host."
  value       = module.compute.ec2_private_ip
}

output "rds_instance_id" {
  description = "Shared PostgreSQL RDS identifier."
  value       = module.database.rds_instance_id
}

output "rds_address" {
  description = "Private PostgreSQL hostname for application JDBC connections."
  value       = module.database.rds_address
}

output "rds_port" {
  description = "PostgreSQL TCP port."
  value       = module.database.rds_port
}

output "rds_admin_secret_arn" {
  description = "ARN of the RDS-managed admin secret; does not expose the password."
  value       = module.database.rds_admin_secret_arn
}

output "database_secret_arns" {
  description = "Application database secret ARNs by environment; credential values are not managed or exposed by Terraform."
  value       = module.database.database_secret_arns
}

output "ecr_repository_url" {
  description = "PetClinic image repository URL shared by staging and production."
  value       = module.registry.repository_url
}

output "github_actions_role_arn" {
  description = "Role ARN for GitHub Actions OIDC authentication from this repository's main branch."
  value       = module.pipeline.github_actions_role_arn
}

output "github_notifications_role_arn" {
  description = "Publish-only GitHub OIDC role for main-branch and pull-request failure notifications."
  value       = module.pipeline.github_notifications_role_arn
}

output "pipeline_failure_topic_arn" {
  description = "SNS topic ARN for GitHub pipeline failure messages."
  value       = module.pipeline.pipeline_failure_topic_arn
}

output "alb_dns_name" {
  description = "Public DNS name of the shared application load balancer."
  value       = module.load_balancer.alb_dns_name
}

output "alb_arn" {
  description = "Shared ALB ARN for monitoring and operational checks."
  value       = module.load_balancer.alb_arn
}

output "application_urls" {
  description = "HTTP entry points by environment; application deployment and healthy targets are required."
  value       = module.load_balancer.application_urls
}

output "logging_destinations" {
  description = "Central log destinations; access-log objects expire by lifecycle, and CloudWatch groups have bounded retention."
  value       = module.logging.logging_destinations
}

output "monitoring_dashboards" {
  description = "CloudWatch console links; dashboards populate only after infrastructure and traffic exist."
  value       = module.monitoring.monitoring_dashboards
}
