resource "aws_ecr_repository" "petclinic" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${var.project_name}-petclinic-images" }
}

resource "aws_ecr_lifecycle_policy" "petclinic" {
  repository = aws_ecr_repository.petclinic.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain the newest ${var.ecr_retained_image_count} images for deployment and rollback"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.ecr_retained_image_count
      }
      action = { type = "expire" }
    }]
  })
}
