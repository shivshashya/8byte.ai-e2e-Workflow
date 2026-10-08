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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
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
        Resource = aws_ecr_repository.petclinic.arn
      },
      {
        Sid      = "ApplicationSshTunnel"
        Effect   = "Allow"
        Action   = "ec2-instance-connect:OpenTunnel"
        Resource = aws_ec2_instance_connect_endpoint.ssh.arn
        Condition = {
          NumericEquals = { "ec2-instance-connect:remotePort" = "22" }
          IpAddress     = { "ec2-instance-connect:privateIpAddress" = "${aws_instance.application.private_ip}/32" }
        }
      },
      {
        Sid      = "ApplicationSshKey"
        Effect   = "Allow"
        Action   = "ec2-instance-connect:SendSSHPublicKey"
        Resource = aws_instance.application.arn
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
        Resource = aws_ecr_repository.petclinic.arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "application" {
  name = "${var.project_name}-application"
  role = aws_iam_role.application.name
}
