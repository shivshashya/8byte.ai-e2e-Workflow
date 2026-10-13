# All resources and data sources are mocked; this test never contacts AWS.
mock_provider "aws" {
  override_during = plan

  mock_resource "aws_instance" {
    defaults = { id = "i-0123456789abcdef0" }
  }
  mock_resource "aws_lb" {
    defaults = {
      arn_suffix = "app/test/0123456789abcdef"
      arn        = "arn:aws:elasticloadbalancing:us-east-1:239799717936:loadbalancer/app/test/0123456789abcdef"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn_suffix = "targetgroup/test/0123456789abcdef" }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:239799717936:listener/app/test/0123456789abcdef/0123456789abcdef" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::test-alb-logs", id = "test-alb-logs" }
  }
}

override_resource {
  target          = module.logging.aws_cloudwatch_log_group.system
  override_during = plan
  values          = { arn = "arn:aws:logs:us-east-1:239799717936:log-group:/8byte-devops/system" }
}

override_resource {
  target          = module.logging.aws_cloudwatch_log_group.application
  override_during = plan
  values          = { arn = "arn:aws:logs:us-east-1:239799717936:log-group:/8byte-devops/application" }
}

override_resource {
  target          = module.load_balancer.aws_lb_target_group.application["staging"]
  override_during = plan
  values = {
    arn_suffix = "targetgroup/staging/0123456789abcdef"
    arn        = "arn:aws:elasticloadbalancing:us-east-1:239799717936:targetgroup/staging/0123456789abcdef"
  }
}

override_resource {
  target          = module.load_balancer.aws_lb_target_group.application["production"]
  override_during = plan
  values = {
    arn_suffix = "targetgroup/production/0123456789abcdef"
    arn        = "arn:aws:elasticloadbalancing:us-east-1:239799717936:targetgroup/production/0123456789abcdef"
  }
}

run "monitoring_contract" {
  command = plan

  assert {
    condition = (
      jsondecode(module.logging.cloudwatch_agent_config).metrics.namespace == jsondecode(module.compute.metrics_policy).Statement[0].Condition.StringEquals["cloudwatch:namespace"] &&
      jsondecode(module.logging.cloudwatch_agent_config).metrics.append_dimensions.InstanceId == "$${aws:InstanceId}" &&
      jsondecode(module.logging.cloudwatch_agent_config).agent.metrics_collection_interval == 60 &&
      jsondecode(module.logging.cloudwatch_agent_config).metrics.metrics_collected.disk.resources == ["/"]
    )
    error_message = "The host collector must use the permitted namespace, runtime instance ID, standard resolution and root filesystem."
  }

  assert {
    condition = (
      strcontains(module.compute.user_data, base64encode(module.logging.cloudwatch_agent_config)) &&
      strcontains(module.compute.user_data, "amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:") &&
      jsondecode(module.monitoring.dashboard_bodies.infrastructure).widgets[1].properties.metrics[0][0] == module.logging.host_metric_namespace &&
      jsondecode(module.monitoring.dashboard_bodies.infrastructure).widgets[1].properties.metrics[0][3] == module.compute.ec2_instance_id
    )
    error_message = "Bootstrap must install the rendered configuration and the dashboard must select the collector's namespace and instance."
  }

  assert {
    condition = alltrue([
      for index, environment in sort(keys(var.application_ports)) : (
        jsondecode(module.monitoring.dashboard_bodies.application).widgets[index * 4].properties.metrics[0][1] == "RequestCount" &&
        jsondecode(module.monitoring.dashboard_bodies.application).widgets[index * 4].properties.metrics[0][5] == module.load_balancer.target_group_arn_suffixes[environment] &&
        jsondecode(module.monitoring.dashboard_bodies.application).widgets[index * 4].properties.stat == "Sum" &&
        jsondecode(module.monitoring.dashboard_bodies.application).widgets[index * 4].properties.period == 60 &&
        jsondecode(module.monitoring.dashboard_bodies.application).widgets[index * 4 + 1].properties.metrics[2][0].expression == "IF(requests > 0, 100 * FILL(errors, 0) / requests)" &&
        jsondecode(module.monitoring.dashboard_bodies.application).widgets[index * 4 + 2].properties.metrics[1][6].stat == "p95"
      )
    ])
    error_message = "Each environment must use its own target group, total requests per minute, a traffic-guarded error percentage and p95 latency."
  }
}

run "logging_contract" {
  command = plan

  assert {
    condition = (
      module.logging.log_groups.system.retention_in_days == 14 &&
      module.logging.log_groups.application.retention_in_days == 14 &&
      length(jsondecode(module.logging.cloudwatch_agent_config).logs.logs_collected.files.collect_list) == 3 &&
      alltrue([for file in jsondecode(module.logging.cloudwatch_agent_config).logs.logs_collected.files.collect_list :
        file.log_group_name == module.logging.log_groups.system.name && startswith(file.log_stream_name, "{instance_id}/")
      ]) &&
      strcontains(module.compute.user_data, module.logging.docker_logging_config)
    )
    error_message = "System file collection, rendered Docker logging and bounded log retention must be wired into bootstrap."
  }

  assert {
    condition = (
      jsondecode(module.logging.docker_logging_config)["log-driver"] == "awslogs" &&
      jsondecode(module.logging.docker_logging_config)["log-opts"]["tag"] == "{{.Name}}/{{.FullID}}" &&
      jsondecode(module.logging.docker_logging_config)["log-opts"]["awslogs-group"] == module.logging.log_groups.application.name &&
      jsondecode(module.logging.docker_logging_config)["log-opts"]["awslogs-create-group"] == "false" &&
      jsondecode(module.logging.docker_logging_config)["log-opts"]["mode"] == "non-blocking" &&
      jsondecode(module.logging.docker_logging_config)["log-opts"]["cache-max-size"] == "10m" &&
      jsondecode(module.logging.docker_logging_config)["log-opts"]["cache-max-file"] == "3" &&
      toset(jsondecode(module.compute.logs_policy).Statement[0].Resource) == toset([
        "${module.logging.log_groups.system.arn}:*", "${module.logging.log_groups.application.arn}:*"
      ]) &&
      !contains(jsondecode(module.compute.logs_policy).Statement[0].Action, "logs:CreateLogGroup")
    )
    error_message = "Container streams must identify their environment and incarnation; host log writes must be restricted to precreated groups."
  }

  assert {
    condition = (
      module.load_balancer.access_logs[0].enabled &&
      module.load_balancer.access_logs[0].bucket == module.logging.alb_log_bucket.bucket &&
      module.load_balancer.access_logs[0].prefix == "alb" &&
      module.logging.alb_logs_public_access.block_public_policy &&
      module.logging.alb_logs_public_access.block_public_acls &&
      module.logging.alb_logs_public_access.ignore_public_acls &&
      module.logging.alb_logs_public_access.restrict_public_buckets &&
      one(one(module.logging.alb_logs_encryption_rules).apply_server_side_encryption_by_default).sse_algorithm == "AES256" &&
      one(one(module.logging.alb_logs_lifecycle_rules).expiration).days == 30 &&
      jsondecode(module.logging.alb_logs_policy).Statement[0].Resource == "${module.logging.alb_log_bucket.arn}/alb/AWSLogs/${var.aws_account_id}/*" &&
      jsondecode(module.logging.alb_logs_policy).Statement[0].Principal.Service == "logdelivery.elasticloadbalancing.amazonaws.com" &&
      !module.logging.alb_log_bucket.force_destroy
    )
    error_message = "ALB delivery must use a private SSE-S3 bucket with account-scoped writes, 30-day expiration and protected nonempty deletion."
  }
}
