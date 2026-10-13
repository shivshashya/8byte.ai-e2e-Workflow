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
          [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "ALB 5xx (shared)" }]],
          [for environment in sort(keys(var.application_ports)) : ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffixes[environment], { label = "${environment} target 4xx" }]]
        )
      }
    }])
  })
}
