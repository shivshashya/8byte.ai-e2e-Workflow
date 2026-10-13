locals {
  infrastructure_panels = [
    { title = "Shared host CPU (%) — five-minute average", namespace = "AWS/EC2", names = ["CPUUtilization"], dimension = "InstanceId", value = var.ec2_instance_id, period = 300 },
    { title = "Shared host memory and root disk used (%)", namespace = var.host_metric_namespace, names = ["mem_used_percent", "disk_used_percent"], dimension = "InstanceId", value = var.ec2_instance_id, period = 60 },
    { title = "Shared PostgreSQL CPU (%)", namespace = "AWS/RDS", names = ["CPUUtilization"], dimension = "DBInstanceIdentifier", value = var.rds_identifier, period = 60 },
    { title = "Shared PostgreSQL connections", namespace = "AWS/RDS", names = ["DatabaseConnections"], dimension = "DBInstanceIdentifier", value = var.rds_identifier, period = 60 },
    { title = "Shared PostgreSQL free memory and storage (bytes)", namespace = "AWS/RDS", names = ["FreeableMemory", "FreeStorageSpace"], dimension = "DBInstanceIdentifier", value = var.rds_identifier, period = 60 },
    { title = "Shared PostgreSQL read/write latency (seconds)", namespace = "AWS/RDS", names = ["ReadLatency", "WriteLatency"], dimension = "DBInstanceIdentifier", value = var.rds_identifier, period = 60 },
  ]
  application_widgets = flatten([
    for index, environment in sort(keys(var.application_ports)) : [
      {
        type = "metric", x = 0, y = index * 12, width = 12, height = 6
        properties = {
          title   = "${environment}: requests per minute through ALB", region = var.aws_region, view = "timeSeries", period = 60, stat = "Sum"
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffixes[environment]]]
        }
      },
      {
        type = "metric", x = 12, y = index * 12, width = 12, height = 6
        properties = {
          title = "${environment}: target 5xx error percentage", region = var.aws_region, view = "timeSeries", period = 60, stat = "Sum"
          yAxis = { left = { min = 0, max = 100 } }
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffixes[environment], { id = "requests", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffixes[environment], { id = "errors", visible = false }],
            [{ expression = "IF(requests > 0, 100 * FILL(errors, 0) / requests)", id = "error_rate", label = "Target 5xx (%)" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = index * 12 + 6, width = 12, height = 6
        properties = {
          title = "${environment}: target response time (seconds)", region = var.aws_region, view = "timeSeries", period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffixes[environment], { stat = "Average", label = "Average" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffixes[environment], { stat = "p95", label = "p95" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = index * 12 + 6, width = 12, height = 6
        properties = {
          title = "${environment}: target availability", region = var.aws_region, view = "timeSeries", period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffixes[environment], { stat = "Minimum" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffixes[environment], { stat = "Maximum" }],
          ]
        }
      },
    ]
  ])
}
