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
  target          = aws_cloudwatch_log_group.system
  override_during = plan
  values          = { arn = "arn:aws:logs:us-east-1:239799717936:log-group:/8byte-devops/system" }
}

override_resource {
  target          = aws_cloudwatch_log_group.application
  override_during = plan
  values          = { arn = "arn:aws:logs:us-east-1:239799717936:log-group:/8byte-devops/application" }
}

override_resource {
  target          = aws_lb_target_group.application["staging"]
  override_during = plan
  values = {
    arn_suffix = "targetgroup/staging/0123456789abcdef"
    arn        = "arn:aws:elasticloadbalancing:us-east-1:239799717936:targetgroup/staging/0123456789abcdef"
  }
}

override_resource {
  target          = aws_lb_target_group.application["production"]
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
      jsondecode(local.cloudwatch_agent_config).metrics.namespace == jsondecode(aws_iam_role_policy.application_metrics.policy).Statement[0].Condition.StringEquals["cloudwatch:namespace"] &&
      jsondecode(local.cloudwatch_agent_config).metrics.append_dimensions.InstanceId == "$${aws:InstanceId}" &&
      jsondecode(local.cloudwatch_agent_config).agent.metrics_collection_interval == 60 &&
      jsondecode(local.cloudwatch_agent_config).metrics.metrics_collected.disk.resources == ["/"]
    )
    error_message = "The host collector must use the permitted namespace, runtime instance ID, standard resolution and root filesystem."
  }

  assert {
    condition = (
      strcontains(aws_instance.application.user_data, base64encode(local.cloudwatch_agent_config)) &&
      strcontains(aws_instance.application.user_data, "amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:") &&
      jsondecode(aws_cloudwatch_dashboard.infrastructure.dashboard_body).widgets[1].properties.metrics[0][0] == local.host_metric_namespace &&
      jsondecode(aws_cloudwatch_dashboard.infrastructure.dashboard_body).widgets[1].properties.metrics[0][3] == aws_instance.application.id
    )
    error_message = "Bootstrap must install the rendered configuration and the dashboard must select the collector's namespace and instance."
  }

  assert {
    condition = alltrue([
      for index, environment in sort(keys(var.application_ports)) : (
        jsondecode(aws_cloudwatch_dashboard.application.dashboard_body).widgets[index * 4].properties.metrics[0][1] == "RequestCount" &&
        jsondecode(aws_cloudwatch_dashboard.application.dashboard_body).widgets[index * 4].properties.metrics[0][5] == aws_lb_target_group.application[environment].arn_suffix &&
        jsondecode(aws_cloudwatch_dashboard.application.dashboard_body).widgets[index * 4].properties.stat == "Sum" &&
        jsondecode(aws_cloudwatch_dashboard.application.dashboard_body).widgets[index * 4].properties.period == 60 &&
        jsondecode(aws_cloudwatch_dashboard.application.dashboard_body).widgets[index * 4 + 1].properties.metrics[2][0].expression == "IF(requests > 0, 100 * FILL(errors, 0) / requests)" &&
        jsondecode(aws_cloudwatch_dashboard.application.dashboard_body).widgets[index * 4 + 2].properties.metrics[1][6].stat == "p95"
      )
    ])
    error_message = "Each environment must use its own target group, total requests per minute, a traffic-guarded error percentage and p95 latency."
  }
}

run "logging_contract" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_log_group.system.retention_in_days == 14 &&
      aws_cloudwatch_log_group.application.retention_in_days == 14 &&
      length(jsondecode(local.cloudwatch_agent_config).logs.logs_collected.files.collect_list) == 3 &&
      alltrue([for file in jsondecode(local.cloudwatch_agent_config).logs.logs_collected.files.collect_list :
        file.log_group_name == aws_cloudwatch_log_group.system.name && startswith(file.log_stream_name, "{instance_id}/")
      ]) &&
      strcontains(aws_instance.application.user_data, local.docker_logging_config)
    )
    error_message = "System file collection, rendered Docker logging and bounded log retention must be wired into bootstrap."
  }

  assert {
    condition = (
      jsondecode(local.docker_logging_config)["log-driver"] == "awslogs" &&
      jsondecode(local.docker_logging_config)["log-opts"]["tag"] == "{{.Name}}/{{.FullID}}" &&
      jsondecode(local.docker_logging_config)["log-opts"]["awslogs-group"] == aws_cloudwatch_log_group.application.name &&
      jsondecode(local.docker_logging_config)["log-opts"]["awslogs-create-group"] == "false" &&
      jsondecode(local.docker_logging_config)["log-opts"]["mode"] == "non-blocking" &&
      jsondecode(local.docker_logging_config)["log-opts"]["cache-max-size"] == "10m" &&
      jsondecode(local.docker_logging_config)["log-opts"]["cache-max-file"] == "3" &&
      toset(jsondecode(aws_iam_role_policy.application_logs.policy).Statement[0].Resource) == toset([
        "${aws_cloudwatch_log_group.system.arn}:*", "${aws_cloudwatch_log_group.application.arn}:*"
      ]) &&
      !contains(jsondecode(aws_iam_role_policy.application_logs.policy).Statement[0].Action, "logs:CreateLogGroup")
    )
    error_message = "Container streams must identify their environment and incarnation; host log writes must be restricted to precreated groups."
  }

  assert {
    condition = (
      aws_lb.application.access_logs[0].enabled &&
      aws_lb.application.access_logs[0].bucket == aws_s3_bucket.alb_logs.bucket &&
      aws_lb.application.access_logs[0].prefix == "alb" &&
      aws_s3_bucket_public_access_block.alb_logs.block_public_policy &&
      aws_s3_bucket_public_access_block.alb_logs.block_public_acls &&
      aws_s3_bucket_public_access_block.alb_logs.ignore_public_acls &&
      aws_s3_bucket_public_access_block.alb_logs.restrict_public_buckets &&
      one(one(aws_s3_bucket_server_side_encryption_configuration.alb_logs.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256" &&
      one(one(aws_s3_bucket_lifecycle_configuration.alb_logs.rule).expiration).days == 30 &&
      jsondecode(aws_s3_bucket_policy.alb_logs.policy).Statement[0].Resource == "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${var.aws_account_id}/*" &&
      jsondecode(aws_s3_bucket_policy.alb_logs.policy).Statement[0].Principal.Service == "logdelivery.elasticloadbalancing.amazonaws.com" &&
      !aws_s3_bucket.alb_logs.force_destroy
    )
    error_message = "ALB delivery must use a private SSE-S3 bucket with account-scoped writes, 30-day expiration and protected nonempty deletion."
  }
}
