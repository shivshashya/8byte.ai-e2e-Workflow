output "vpc_id" {
  description = "Shared VPC ID."
  value       = aws_vpc.vpc_8byte_ai.id
}

output "vpc_cidr" {
  description = "Shared VPC IPv4 range."
  value       = aws_vpc.vpc_8byte_ai.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered by logical Availability Zone."
  value = {
    a = aws_subnet.public_a.id
    b = aws_subnet.public_b.id
  }

  # The ALB must receive subnets with working public routing.
  depends_on = [
    aws_route.public_internet,
    aws_route_table_association.public_a,
    aws_route_table_association.public_b,
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, ordered by logical Availability Zone."
  value = {
    a = aws_subnet.private_a.id
    b = aws_subnet.private_b.id
  }
}

output "application_subnet_id" {
  description = "Private subnet A ID, available after the NAT route is ready for bootstrap downloads."
  value       = aws_subnet.private_a.id
  depends_on  = [aws_route.private_a_internet]
}

output "internet_gateway_id" {
  description = "Internet gateway ID."
  value       = aws_internet_gateway.main.id
}

output "route_table_ids" {
  description = "Public and private route-table IDs."
  value = {
    public    = aws_route_table.public.id
    private_a = aws_route_table.private_a.id
    private_b = aws_route_table.private_b.id
  }
}

output "security_group_ids" {
  description = "Security groups for each traffic boundary."
  value = {
    alb          = aws_security_group.alb.id
    ec2          = aws_security_group.ec2.id
    rds          = aws_security_group.rds.id
    ssh_endpoint = aws_security_group.ssh_endpoint.id
  }
}

output "ssh_endpoint_id" {
  description = "SSH endpoint ID."
  value       = aws_ec2_instance_connect_endpoint.ssh.id
}

output "ssh_endpoint_arn" {
  description = "SSH endpoint ARN for IAM policies."
  value       = aws_ec2_instance_connect_endpoint.ssh.arn
}

output "nat_gateway_id" {
  description = "NAT gateway ID."
  value       = aws_nat_gateway.main.id
}

output "nat_public_ip" {
  description = "NAT public IPv4 address."
  value       = aws_eip.nat.public_ip
}
