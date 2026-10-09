# Keep rules separate so groups can reference each other without dependency cycles.
# Terraform removes AWS's default allow-all outbound rule for these groups.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "HTTP entry point and access to application ports on EC2"
  vpc_id      = aws_vpc.vpc_8byte_ai.id

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2"
  description = "Application traffic from ALB and SSH from the connect endpoint"
  vpc_id      = aws_vpc.vpc_8byte_ai.id

  tags = { Name = "${var.project_name}-ec2" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds"
  description = "PostgreSQL connections from the application EC2 group"
  vpc_id      = aws_vpc.vpc_8byte_ai.id

  tags = { Name = "${var.project_name}-rds" }
}

resource "aws_security_group" "ssh_endpoint" {
  name        = "${var.project_name}-ssh-endpoint"
  description = "SSH tunnel access to the application EC2 group"
  vpc_id      = aws_vpc.vpc_8byte_ai.id

  tags = { Name = "${var.project_name}-ssh-endpoint" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTP access to the ALB"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = var.alb_listener_ports.production
  to_port           = var.alb_listener_ports.production
}

resource "aws_vpc_security_group_ingress_rule" "alb_staging_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Public staging HTTP access to the ALB"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = var.alb_listener_ports.staging
  to_port           = var.alb_listener_ports.staging
}

# Both sides must permit each ALB-to-EC2 connection.
resource "aws_vpc_security_group_egress_rule" "alb_to_application" {
  for_each = var.application_ports

  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ec2.id
  description                  = "ALB requests and health checks for ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_vpc_security_group_ingress_rule" "application_from_alb" {
  for_each = var.application_ports

  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "${each.key} application traffic from the ALB"
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_postgres" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.rds.id
  description                  = "Application connections to PostgreSQL"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ec2.id
  description                  = "PostgreSQL access from application EC2"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# Package downloads, image pulls, and AWS HTTPS APIs need a future outbound route.
# These permissions alone do not give the private subnet internet access.
resource "aws_vpc_security_group_egress_rule" "ec2_web" {
  for_each = { http = 80, https = 443 }

  security_group_id = aws_security_group.ec2.id
  description       = "Outbound ${each.key} for packages, images, and service APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
}

resource "aws_vpc_security_group_egress_rule" "endpoint_to_ssh" {
  security_group_id            = aws_security_group.ssh_endpoint.id
  referenced_security_group_id = aws_security_group.ec2.id
  description                  = "Endpoint tunnels to EC2 SSH"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_endpoint" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.ssh_endpoint.id
  description                  = "SSH access through the connect endpoint"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

# RDS needs no outbound rule for replies: security groups are stateful.
# Endpoint inbound access is controlled by IAM, not endpoint ingress rules.
