# Both private subnets are required for the subnet group; the DB is Single-AZ.
resource "aws_db_subnet_group" "application" {
  name       = "rds-${var.project_name}"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = { Name = "${var.project_name}-rds-subnets" }
}

resource "aws_db_parameter_group" "application" {
  name   = "rds-${var.project_name}-postgres${split(".", var.rds_engine_version)[0]}"
  family = "postgres${split(".", var.rds_engine_version)[0]}"

  # Explicitly override PostgreSQL 15+ defaults: TLS is optional by user choice.
  parameter {
    name         = "rds.force_ssl"
    value        = var.rds_require_tls ? "1" : "0"
    apply_method = "pending-reboot"
  }

  tags = { Name = "${var.project_name}-postgres-parameters" }
}

resource "aws_db_instance" "application" {
  identifier     = "petclinic-${var.project_name}"
  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage = var.rds_storage_gib
  storage_type      = "gp3"
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.application.name
  parameter_group_name   = aws_db_parameter_group.application.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  availability_zone      = var.availability_zones[0]
  multi_az               = false
  publicly_accessible    = false
  port                   = 5432

  # RDS generates/stores the admin password; Terraform never reads its value.
  username                    = var.rds_admin_username
  manage_master_user_password = true

  backup_retention_period     = var.rds_backup_retention_days
  backup_window               = "01:00-01:30"
  maintenance_window          = "sun:02:00-sun:03:00"
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = false

  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = coalesce(var.rds_final_snapshot_identifier, "petclinic-${var.project_name}-final")
  copy_tags_to_snapshot     = true

  # app_staging/app_production and restricted users are initialized after apply.
  # No application or master password is supplied in Terraform configuration.
  tags = {
    Name = "${var.project_name}-postgres"
    Role = "shared-database"
  }
}
