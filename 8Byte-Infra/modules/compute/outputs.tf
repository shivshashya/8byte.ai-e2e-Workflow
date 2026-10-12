output "ec2_instance_id" {
  description = "Application EC2 instance ID."
  value       = aws_instance.application.id
}

output "ec2_instance_arn" {
  description = "Application EC2 instance ARN."
  value       = aws_instance.application.arn
}

output "ec2_private_ip" {
  description = "Application private IPv4 address."
  value       = aws_instance.application.private_ip
}

output "user_data" {
  description = "Rendered bootstrap script for inspection and contract tests; contains no database credentials."
  value       = aws_instance.application.user_data
}

output "metrics_policy" {
  description = "Scoped host metric publishing policy."
  value       = aws_iam_role_policy.application_metrics.policy
}

output "logs_policy" {
  description = "Scoped centralized log writing policy."
  value       = aws_iam_role_policy.application_logs.policy
}
