resource "aws_sns_topic" "pipeline_failures" {
  name = "${var.project_name}-pipeline-failures"

  tags = { Name = "${var.project_name}-pipeline-failures" }
}

resource "aws_sns_topic_subscription" "pipeline_failure_email" {
  topic_arn = aws_sns_topic.pipeline_failures.arn
  protocol  = "email"
  endpoint  = var.pipeline_alert_email

  # AWS emails a confirmation link. Delivery starts only after owner confirmation.
}
