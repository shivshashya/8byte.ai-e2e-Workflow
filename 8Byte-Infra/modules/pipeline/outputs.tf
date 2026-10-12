output "github_actions_role_arn" {
  description = "GitHub deployment role ARN."
  value       = aws_iam_role.github_actions.arn
}

output "github_notifications_role_arn" {
  description = "GitHub failure notification role ARN."
  value       = aws_iam_role.github_notifications.arn
}

output "pipeline_failure_topic_arn" {
  description = "Pipeline failure SNS topic ARN."
  value       = aws_sns_topic.pipeline_failures.arn
}
