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
