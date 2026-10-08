resource "aws_ec2_instance_connect_endpoint" "ssh" {
  # Keep this in the same subnet/AZ as the planned EC2 instance.
  subnet_id          = aws_subnet.private_a.id
  security_group_ids = [aws_security_group.ssh_endpoint.id]
  preserve_client_ip = false

  depends_on = [
    aws_vpc_security_group_egress_rule.endpoint_to_ssh,
    aws_vpc_security_group_ingress_rule.ssh_from_endpoint,
  ]

  tags = { Name = "${var.project_name}-ssh" }
}
