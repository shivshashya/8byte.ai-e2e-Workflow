resource "aws_iam_role" "application" {
  name = "${var.project_name}-application"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}
resource "aws_iam_role_policy" "application_ecr_pull" {
  name = "petclinic-image-pull"
  role = aws_iam_role.application.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid      = "PetclinicPull"
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
        Resource = var.ecr_repository_arn
      },
    ]
  })
}
resource "aws_iam_instance_profile" "application" {
  name = "${var.project_name}-application"
  role = aws_iam_role.application.name
}

resource "aws_iam_role_policy" "application_database_secrets" {
  name = "petclinic-database-secrets-read"
  role = aws_iam_role.application.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadApplicationDatabaseCredentials"
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = values(var.database_secret_arns)
    }]
  })
}

resource "aws_iam_role_policy" "application_logs" {
  name = "publish-system-and-container-logs"
  role = aws_iam_role.application.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
      Resource = [
        "${var.log_group_arns.system}:*",
        "${var.log_group_arns.application}:*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "application_metrics" {
  name = "publish-host-metrics"
  role = aws_iam_role.application.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow", Action = "cloudwatch:PutMetricData", Resource = "*"
      Condition = { StringEquals = { "cloudwatch:namespace" = var.host_metric_namespace } }
    }]
  })
}
