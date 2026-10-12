# Compose one shared infrastructure stack for both application environments.
# Module interfaces define dependencies; provider and state configuration stay here.

module "network" {
  source = "./modules/network"

  alb_listener_ports   = var.alb_listener_ports
  application_ports    = var.application_ports
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  project_name         = var.project_name
  public_subnet_cidrs  = var.public_subnet_cidrs
  vpc_cidr             = var.vpc_cidr
  vpc_name             = var.vpc_name
}

module "registry" {
  source = "./modules/registry"

  ecr_repository_name      = var.ecr_repository_name
  ecr_retained_image_count = var.ecr_retained_image_count
  project_name             = var.project_name
}

module "database" {
  source = "./modules/database"

  availability_zone             = var.availability_zones[0]
  database_secret_suffix        = var.database_secret_suffix
  private_subnet_ids            = [module.network.private_subnet_ids.a, module.network.private_subnet_ids.b]
  project_name                  = var.project_name
  rds_admin_username            = var.rds_admin_username
  rds_backup_retention_days     = var.rds_backup_retention_days
  rds_deletion_protection       = var.rds_deletion_protection
  rds_engine_version            = var.rds_engine_version
  rds_final_snapshot_identifier = var.rds_final_snapshot_identifier
  rds_instance_class            = var.rds_instance_class
  rds_require_tls               = var.rds_require_tls
  rds_storage_gib               = var.rds_storage_gib
  security_group_id             = module.network.security_group_ids.rds
}

module "logging" {
  source = "./modules/logging"

  alb_access_log_retention_days = var.alb_access_log_retention_days
  aws_account_id                = var.aws_account_id
  aws_region                    = var.aws_region
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
  project_name                  = var.project_name
}

module "compute" {
  source = "./modules/compute"

  cloudwatch_agent_config = module.logging.cloudwatch_agent_config
  database_secret_arns    = module.database.database_secret_arns
  docker_logging_config   = module.logging.docker_logging_config
  ec2_ami_id              = var.ec2_ami_id
  ec2_cpu_credit_mode     = var.ec2_cpu_credit_mode
  ec2_instance_type       = var.ec2_instance_type
  ec2_root_volume_gb      = var.ec2_root_volume_gb
  ecr_repository_arn      = module.registry.repository_arn
  host_metric_namespace   = module.logging.host_metric_namespace
  log_group_arns          = { for name, group in module.logging.log_groups : name => group.arn }
  project_name            = var.project_name
  security_group_id       = module.network.security_group_ids.ec2
  subnet_id               = module.network.application_subnet_id
}

module "load_balancer" {
  source = "./modules/load_balancer"

  access_log_bucket_name  = module.logging.alb_log_bucket.bucket
  alb_deletion_protection = var.alb_deletion_protection
  alb_health_check_path   = var.alb_health_check_path
  alb_listener_ports      = var.alb_listener_ports
  application_ports       = var.application_ports
  ec2_instance_id         = module.compute.ec2_instance_id
  project_name            = var.project_name
  public_subnet_ids       = [module.network.public_subnet_ids.a, module.network.public_subnet_ids.b]
  security_group_id       = module.network.security_group_ids.alb
  vpc_id                  = module.network.vpc_id

}

module "pipeline" {
  source = "./modules/pipeline"

  ec2_instance_arn     = module.compute.ec2_instance_arn
  ec2_private_ip       = module.compute.ec2_private_ip
  ecr_repository_arn   = module.registry.repository_arn
  github_owner_id      = var.github_owner_id
  github_repository    = var.github_repository
  github_repository_id = var.github_repository_id
  pipeline_alert_email = var.pipeline_alert_email
  project_name         = var.project_name
  ssh_endpoint_arn     = module.network.ssh_endpoint_arn
}

module "monitoring" {
  source = "./modules/monitoring"

  alb_arn_suffix            = module.load_balancer.alb_arn_suffix
  application_ports         = var.application_ports
  aws_region                = var.aws_region
  ec2_instance_id           = module.compute.ec2_instance_id
  host_metric_namespace     = module.logging.host_metric_namespace
  project_name              = var.project_name
  rds_identifier            = module.database.rds_identifier
  target_group_arn_suffixes = module.load_balancer.target_group_arn_suffixes
}
