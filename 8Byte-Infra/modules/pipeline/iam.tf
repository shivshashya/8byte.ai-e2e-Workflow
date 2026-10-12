locals {
  # Verified against GitHub's OIDC customization API; IDs bind trust to this repo.
  github_oidc_subject_prefix = "repo:${split("/", var.github_repository)[0]}@${var.github_owner_id}/${split("/", var.github_repository)[1]}@${var.github_repository_id}"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${local.github_oidc_subject_prefix}:ref:refs/heads/main"
        }
      }
    }]
  })
}
resource "aws_iam_role_policy" "github_actions" {
  name = "petclinic-image-and-ssh-deployment"
  role = aws_iam_role.github_actions.id
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
        Sid    = "PetclinicPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload", "ecr:PutImage",
        ]
        Resource = var.ecr_repository_arn
      },
      {
        Sid      = "ApplicationSshTunnel"
        Effect   = "Allow"
        Action   = "ec2-instance-connect:OpenTunnel"
        Resource = var.ssh_endpoint_arn
        Condition = {
          NumericEquals = { "ec2-instance-connect:remotePort" = "22" }
          IpAddress     = { "ec2-instance-connect:privateIpAddress" = "${var.ec2_private_ip}/32" }
        }
      },
      {
        Sid      = "ApplicationSshKey"
        Effect   = "Allow"
        Action   = "ec2-instance-connect:SendSSHPublicKey"
        Resource = var.ec2_instance_arn
        Condition = {
          StringEquals = { "ec2:osuser" = "ec2-user" }
        }
      },
      {
        Sid      = "DiscoverSshTarget"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeInstanceConnectEndpoints"]
        Resource = "*"
      },
    ]
  })
}
resource "aws_iam_role" "github_notifications" {
  name = "${var.project_name}-github-notifications"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = [
            "${local.github_oidc_subject_prefix}:ref:refs/heads/main",
            "${local.github_oidc_subject_prefix}:pull_request",
          ]
        }
      }
    }]
  })
}
resource "aws_iam_role_policy" "github_notifications" {
  name = "publish-pipeline-failure"
  role = aws_iam_role.github_notifications.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "PublishPipelineFailure"
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.pipeline_failures.arn
    }]
  })
}
