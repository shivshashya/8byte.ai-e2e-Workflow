output "monitoring_dashboards" {
  description = "CloudWatch console links for both dashboards."
  value = {
    infrastructure = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.infrastructure.dashboard_name}"
    application    = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.application.dashboard_name}"
  }
}

output "dashboard_bodies" {
  description = "Rendered JSON for dashboard inspection and contract tests."
  value = {
    infrastructure = aws_cloudwatch_dashboard.infrastructure.dashboard_body
    application    = aws_cloudwatch_dashboard.application.dashboard_body
  }
}
