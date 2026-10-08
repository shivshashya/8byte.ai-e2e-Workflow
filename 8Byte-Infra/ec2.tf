# Pin the reviewed AMI; upgrades should be intentional rather than automatic.
# Verify the image is Amazon-owned and matches the x86 container architecture.
data "aws_ami" "application" {
  owners = ["amazon"]

  filter {
    name   = "image-id"
    values = [var.ec2_ami_id]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "application" {
  ami                         = data.aws_ami.application.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.application.name

  # First-boot setup only; changes to this script require a reviewed replacement.
  user_data                   = file("${path.module}/scripts/bootstrap_ec2.sh")
  user_data_replace_on_change = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ec2_root_volume_gb
    encrypted             = true
    delete_on_termination = true

    tags = { Name = "${var.project_name}-ec2-root" }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    # Keep metadata responses confined to the host network.
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  credit_specification {
    cpu_credits = var.ec2_cpu_credit_mode
  }

  # Bootstrap downloads need the NAT route.
  depends_on = [
    aws_route.private_a_internet,
  ]

  tags = {
    Name = "${var.project_name}-application"
    Role = "shared-application"
  }
}
