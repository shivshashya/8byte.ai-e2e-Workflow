output "alb_dns_name" {
  description = "Public ALB DNS name."
  value       = aws_lb.application.dns_name
}

output "alb_arn" {
  description = "ALB ARN."
  value       = aws_lb.application.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for metrics."
  value       = aws_lb.application.arn_suffix
}

output "target_group_arns" {
  description = "Target-group ARNs by environment."
  value       = { for environment, target_group in aws_lb_target_group.application : environment => target_group.arn }
}

output "target_group_arn_suffixes" {
  description = "Target-group ARN suffixes for metrics."
  value       = { for environment, target_group in aws_lb_target_group.application : environment => target_group.arn_suffix }
}

output "access_logs" {
  description = "ALB access-log delivery configuration."
  value       = aws_lb.application.access_logs
}

output "application_urls" {
  description = "Public application URLs by environment."
  value       = { for environment, port in var.alb_listener_ports : environment => (port == 80 ? "http://${aws_lb.application.dns_name}" : "http://${aws_lb.application.dns_name}:${port}") }
}
