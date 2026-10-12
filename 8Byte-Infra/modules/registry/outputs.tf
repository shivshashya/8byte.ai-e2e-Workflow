output "repository_url" {
  description = "Shared application image repository URL."
  value       = aws_ecr_repository.petclinic.repository_url
}

output "repository_arn" {
  description = "Shared application image repository ARN."
  value       = aws_ecr_repository.petclinic.arn
}
