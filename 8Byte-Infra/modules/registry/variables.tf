variable "ecr_repository_name" {
  description = "One private image repository shared by staging and production."
  type        = string
}

variable "ecr_retained_image_count" {
  description = "Keep this many newest ECR images; older images may expire even if deployed."
  type        = number

  validation {
    condition     = var.ecr_retained_image_count >= 1 && var.ecr_retained_image_count == floor(var.ecr_retained_image_count)
    error_message = "ecr_retained_image_count must be a positive integer."
  }
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
}
