# Map the previous flat root addresses to their module locations.
# Keep these mappings for compatibility with any retained older state.

moved {
  from = aws_cloudwatch_dashboard.application
  to   = module.monitoring.aws_cloudwatch_dashboard.application
}

moved {
  from = aws_cloudwatch_dashboard.infrastructure
  to   = module.monitoring.aws_cloudwatch_dashboard.infrastructure
}

moved {
  from = aws_cloudwatch_log_group.application
  to   = module.logging.aws_cloudwatch_log_group.application
}

moved {
  from = aws_cloudwatch_log_group.system
  to   = module.logging.aws_cloudwatch_log_group.system
}

moved {
  from = aws_db_instance.application
  to   = module.database.aws_db_instance.application
}

moved {
  from = aws_db_parameter_group.application
  to   = module.database.aws_db_parameter_group.application
}

moved {
  from = aws_db_subnet_group.application
  to   = module.database.aws_db_subnet_group.application
}

moved {
  from = aws_ec2_instance_connect_endpoint.ssh
  to   = module.network.aws_ec2_instance_connect_endpoint.ssh
}

moved {
  from = aws_ecr_lifecycle_policy.petclinic
  to   = module.registry.aws_ecr_lifecycle_policy.petclinic
}

moved {
  from = aws_ecr_repository.petclinic
  to   = module.registry.aws_ecr_repository.petclinic
}

moved {
  from = aws_eip.nat
  to   = module.network.aws_eip.nat
}

moved {
  from = aws_iam_instance_profile.application
  to   = module.compute.aws_iam_instance_profile.application
}

moved {
  from = aws_iam_openid_connect_provider.github
  to   = module.pipeline.aws_iam_openid_connect_provider.github
}

moved {
  from = aws_iam_role.application
  to   = module.compute.aws_iam_role.application
}

moved {
  from = aws_iam_role.github_actions
  to   = module.pipeline.aws_iam_role.github_actions
}

moved {
  from = aws_iam_role.github_notifications
  to   = module.pipeline.aws_iam_role.github_notifications
}

moved {
  from = aws_iam_role_policy.application_database_secrets
  to   = module.compute.aws_iam_role_policy.application_database_secrets
}

moved {
  from = aws_iam_role_policy.application_ecr_pull
  to   = module.compute.aws_iam_role_policy.application_ecr_pull
}

moved {
  from = aws_iam_role_policy.application_logs
  to   = module.compute.aws_iam_role_policy.application_logs
}

moved {
  from = aws_iam_role_policy.application_metrics
  to   = module.compute.aws_iam_role_policy.application_metrics
}

moved {
  from = aws_iam_role_policy.github_actions
  to   = module.pipeline.aws_iam_role_policy.github_actions
}

moved {
  from = aws_iam_role_policy.github_notifications
  to   = module.pipeline.aws_iam_role_policy.github_notifications
}

moved {
  from = aws_instance.application
  to   = module.compute.aws_instance.application
}

moved {
  from = aws_internet_gateway.main
  to   = module.network.aws_internet_gateway.main
}

moved {
  from = aws_lb.application
  to   = module.load_balancer.aws_lb.application
}

moved {
  from = aws_lb_listener.application
  to   = module.load_balancer.aws_lb_listener.application
}

moved {
  from = aws_lb_listener_rule.block_public_actuator
  to   = module.load_balancer.aws_lb_listener_rule.block_public_actuator
}

moved {
  from = aws_lb_target_group.application
  to   = module.load_balancer.aws_lb_target_group.application
}

moved {
  from = aws_lb_target_group_attachment.application
  to   = module.load_balancer.aws_lb_target_group_attachment.application
}

moved {
  from = aws_nat_gateway.main
  to   = module.network.aws_nat_gateway.main
}

moved {
  from = aws_route.private_a_internet
  to   = module.network.aws_route.private_a_internet
}

moved {
  from = aws_route.public_internet
  to   = module.network.aws_route.public_internet
}

moved {
  from = aws_route_table.private_a
  to   = module.network.aws_route_table.private_a
}

moved {
  from = aws_route_table.private_b
  to   = module.network.aws_route_table.private_b
}

moved {
  from = aws_route_table.public
  to   = module.network.aws_route_table.public
}

moved {
  from = aws_route_table_association.private_a
  to   = module.network.aws_route_table_association.private_a
}

moved {
  from = aws_route_table_association.private_b
  to   = module.network.aws_route_table_association.private_b
}

moved {
  from = aws_route_table_association.public_a
  to   = module.network.aws_route_table_association.public_a
}

moved {
  from = aws_route_table_association.public_b
  to   = module.network.aws_route_table_association.public_b
}

moved {
  from = aws_s3_bucket.alb_logs
  to   = module.logging.aws_s3_bucket.alb_logs
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.alb_logs
  to   = module.logging.aws_s3_bucket_lifecycle_configuration.alb_logs
}

moved {
  from = aws_s3_bucket_ownership_controls.alb_logs
  to   = module.logging.aws_s3_bucket_ownership_controls.alb_logs
}

moved {
  from = aws_s3_bucket_policy.alb_logs
  to   = module.logging.aws_s3_bucket_policy.alb_logs
}

moved {
  from = aws_s3_bucket_public_access_block.alb_logs
  to   = module.logging.aws_s3_bucket_public_access_block.alb_logs
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.alb_logs
  to   = module.logging.aws_s3_bucket_server_side_encryption_configuration.alb_logs
}

moved {
  from = aws_secretsmanager_secret.database
  to   = module.database.aws_secretsmanager_secret.database
}

moved {
  from = aws_security_group.alb
  to   = module.network.aws_security_group.alb
}

moved {
  from = aws_security_group.ec2
  to   = module.network.aws_security_group.ec2
}

moved {
  from = aws_security_group.rds
  to   = module.network.aws_security_group.rds
}

moved {
  from = aws_security_group.ssh_endpoint
  to   = module.network.aws_security_group.ssh_endpoint
}

moved {
  from = aws_sns_topic.pipeline_failures
  to   = module.pipeline.aws_sns_topic.pipeline_failures
}

moved {
  from = aws_sns_topic_subscription.pipeline_failure_email
  to   = module.pipeline.aws_sns_topic_subscription.pipeline_failure_email
}

moved {
  from = aws_subnet.private_a
  to   = module.network.aws_subnet.private_a
}

moved {
  from = aws_subnet.private_b
  to   = module.network.aws_subnet.private_b
}

moved {
  from = aws_subnet.public_a
  to   = module.network.aws_subnet.public_a
}

moved {
  from = aws_subnet.public_b
  to   = module.network.aws_subnet.public_b
}

moved {
  from = aws_vpc.vpc_8byte_ai
  to   = module.network.aws_vpc.vpc_8byte_ai
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_to_application
  to   = module.network.aws_vpc_security_group_egress_rule.alb_to_application
}

moved {
  from = aws_vpc_security_group_egress_rule.ec2_to_postgres
  to   = module.network.aws_vpc_security_group_egress_rule.ec2_to_postgres
}

moved {
  from = aws_vpc_security_group_egress_rule.ec2_web
  to   = module.network.aws_vpc_security_group_egress_rule.ec2_web
}

moved {
  from = aws_vpc_security_group_egress_rule.endpoint_to_ssh
  to   = module.network.aws_vpc_security_group_egress_rule.endpoint_to_ssh
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_http
  to   = module.network.aws_vpc_security_group_ingress_rule.alb_http
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_staging_http
  to   = module.network.aws_vpc_security_group_ingress_rule.alb_staging_http
}

moved {
  from = aws_vpc_security_group_ingress_rule.application_from_alb
  to   = module.network.aws_vpc_security_group_ingress_rule.application_from_alb
}

moved {
  from = aws_vpc_security_group_ingress_rule.postgres_from_ec2
  to   = module.network.aws_vpc_security_group_ingress_rule.postgres_from_ec2
}

moved {
  from = aws_vpc_security_group_ingress_rule.ssh_from_endpoint
  to   = module.network.aws_vpc_security_group_ingress_rule.ssh_from_endpoint
}

moved {
  from = data.aws_ami.application
  to   = module.compute.data.aws_ami.application
}
