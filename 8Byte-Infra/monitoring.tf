locals {
  host_metric_namespace = "${var.project_name}/Host"
  cloudwatch_agent_config = jsonencode({
    agent = { metrics_collection_interval = 60, region = var.aws_region }
    logs = {
      force_flush_interval = 5
      logs_collected = {
        files = {
          collect_list = [for name, path in local.system_log_files : {
            file_path       = path
            log_group_name  = aws_cloudwatch_log_group.system.name
            log_stream_name = "{instance_id}/${name}"
          }]
        }
      }
    }
    metrics = {
      namespace              = local.host_metric_namespace
      append_dimensions      = { InstanceId = "$${aws:InstanceId}" }
      aggregation_dimensions = [["InstanceId"]]
      metrics_collected = {
        mem = {
          measurement           = ["used_percent"]
          drop_original_metrics = ["mem_used_percent"]
        }
        disk = {
          resources             = ["/"]
          measurement           = ["used_percent"]
          drop_device           = true
          drop_original_metrics = ["disk_used_percent"]
        }
      }
    }
  })

  infrastructure_panels = [
    { title = "Shared host CPU (%) — five-minute average", namespace = "AWS/EC2", names = ["CPUUtilization"], dimension = "InstanceId", value = aws_instance.application.id, period = 300 },
    { title = "Shared host memory and root disk used (%)", namespace = local.host_metric_namespace, names = ["mem_used_percent", "disk_used_percent"], dimension = "InstanceId", value = aws_instance.application.id, period = 60 },
    { title = "Shared PostgreSQL CPU (%)", namespace = "AWS/RDS", names = ["CPUUtilization"], dimension = "DBInstanceIdentifier", value = aws_db_instance.application.identifier, period = 60 },
    { title = "Shared PostgreSQL connections", namespace = "AWS/RDS", names = ["DatabaseConnections"], dimension = "DBInstanceIdentifier", value = aws_db_instance.application.identifier, period = 60 },
    { title = "Shared PostgreSQL free memory and storage (bytes)", namespace = "AWS/RDS", names = ["FreeableMemory", "FreeStorageSpace"], dimension = "DBInstanceIdentifier", value = aws_db_instance.application.identifier, period = 60 },
    { title = "Shared PostgreSQL read/write latency (seconds)", namespace = "AWS/RDS", names = ["ReadLatency", "WriteLatency"], dimension = "DBInstanceIdentifier", value = aws_db_instance.application.identifier, period = 60 },
  ]
  application_widgets = flatten([
    for index, environment in sort(keys(var.application_ports)) : [
      {
        type = "metric", x = 0, y = index * 12, width = 12, height = 6
        properties = {
          title   = "${environment}: requests per minute through ALB", region = var.aws_region, view = "timeSeries", period = 60, stat = "Sum"
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.application.arn_suffix, "TargetGroup", aws_lb_target_group.application[environment].arn_suffix]]
        }
      },
      {
        type = "metric", x = 12, y = index * 12, width = 12, height = 6
        properties = {
          title = "${environment}: target 5xx error percentage", region = var.aws_region, view = "timeSeries", period = 60, stat = "Sum"
          yAxis = { left = { min = 0, max = 100 } }
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.application.arn_suffix, "TargetGroup", aws_lb_target_group.application[environment].arn_suffix, { id = "requests", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.application.arn_suffix, "TargetGroup", aws_lb_target_group.application[environment].arn_suffix, { id = "errors", visible = false }],
            [{ expression = "IF(requests > 0, 100 * FILL(errors, 0) / requests)", id = "error_rate", label = "Target 5xx (%)" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = index * 12 + 6, width = 12, height = 6
        properties = {
          title = "${environment}: target response time (seconds)", region = var.aws_region, view = "timeSeries", period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.application.arn_suffix, "TargetGroup", aws_lb_target_group.application[environment].arn_suffix, { stat = "Average", label = "Average" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.application.arn_suffix, "TargetGroup", aws_lb_target_group.application[environment].arn_suffix, { stat = "p95", label = "p95" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = index * 12 + 6, width = 12, height = 6
        properties = {
          title = "${environment}: target availability", region = var.aws_region, view = "timeSeries", period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.application.arn_suffix, "TargetGroup", aws_lb_target_group.application[environment].arn_suffix, { stat = "Minimum" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.application.arn_suffix, "TargetGroup", aws_lb_target_group.application[environment].arn_suffix, { stat = "Maximum" }],
          ]
        }
      },
    ]
  ])
}

resource "aws_iam_role_policy" "application_metrics" {
  name = "publish-host-metrics"
  role = aws_iam_role.application.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow", Action = "cloudwatch:PutMetricData", Resource = "*"
      Condition = { StringEquals = { "cloudwatch:namespace" = local.host_metric_namespace } }
    }]
  })
}

resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "${var.project_name}-infrastructure-database"
  dashboard_body = jsonencode({
    periodOverride = "inherit"
    widgets = [for index, panel in local.infrastructure_panels : {
      type = "metric", x = (index % 2) * 12, y = floor(index / 2) * 6, width = 12, height = 6
      properties = {
        title   = panel.title, region = var.aws_region, view = "timeSeries", stat = "Average", period = panel.period
        metrics = [for name in panel.names : [panel.namespace, name, panel.dimension, panel.value]]
      }
    }]
  })
}

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.project_name}-application"
  dashboard_body = jsonencode({
    periodOverride = "inherit"
    widgets = concat(local.application_widgets, [{
      type = "metric", x = 0, y = length(var.application_ports) * 12, width = 24, height = 6
      properties = {
        title = "Shared ALB-generated 5xx and target 4xx responses per minute", region = var.aws_region, view = "timeSeries", period = 60, stat = "Sum"
        metrics = concat(
          [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.application.arn_suffix, { label = "ALB 5xx (shared)" }]],
          [for environment in sort(keys(var.application_ports)) : ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", aws_lb.application.arn_suffix, "TargetGroup", aws_lb_target_group.application[environment].arn_suffix, { label = "${environment} target 4xx" }]]
        )
      }
    }])
  })
}

output "monitoring_dashboards" {
  description = "CloudWatch console links; dashboards populate only after infrastructure and traffic exist."
  value = {
    infrastructure = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.infrastructure.dashboard_name}"
    application    = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.application.dashboard_name}"
  }
}
