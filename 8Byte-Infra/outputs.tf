output "vpc_id" {
  description = "ID of the shared application VPC."
  value       = aws_vpc.vpc_8byte_ai.id
}

output "vpc_cidr" {
  description = "IPv4 CIDR range of the shared application VPC."
  value       = aws_vpc.vpc_8byte_ai.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the two subnets intended for the internet-facing ALB."
  value = {
    a = aws_subnet.public_a.id
    b = aws_subnet.public_b.id
  }
}

output "private_subnet_ids" {
  description = "IDs of the private subnets intended for EC2 and the RDS subnet group."
  value = {
    a = aws_subnet.private_a.id
    b = aws_subnet.private_b.id
  }
}

output "internet_gateway_id" {
  description = "ID of the internet gateway attached to the VPC."
  value       = aws_internet_gateway.main.id
}

output "route_table_ids" {
  description = "IDs of the public route table and each private subnet's route table."
  value = {
    public    = aws_route_table.public.id
    private_a = aws_route_table.private_a.id
    private_b = aws_route_table.private_b.id
  }
}

output "security_group_ids" {
  description = "Security groups for ALB, application EC2, PostgreSQL, and the SSH endpoint."
  value = {
    alb          = aws_security_group.alb.id
    ec2          = aws_security_group.ec2.id
    rds          = aws_security_group.rds.id
    ssh_endpoint = aws_security_group.ssh_endpoint.id
  }
}

output "ssh_endpoint_id" {
  description = "EC2 Instance Connect Endpoint ID for SSH to the planned private EC2 host."
  value       = aws_ec2_instance_connect_endpoint.ssh.id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway providing outbound IPv4 access for private subnet A."
  value       = aws_nat_gateway.main.id
}

output "nat_public_ip" {
  description = "Public IPv4 address used by outbound connections through the NAT gateway."
  value       = aws_eip.nat.public_ip
}

output "ec2_instance_id" {
  description = "Shared application instance ID for SSH access and deployment targeting."
  value       = aws_instance.application.id
}

output "ec2_private_ip" {
  description = "Private IPv4 address of the shared application host."
  value       = aws_instance.application.private_ip
}

output "rds_instance_id" {
  description = "Shared PostgreSQL RDS identifier."
  value       = aws_db_instance.application.id
}

output "rds_address" {
  description = "Private PostgreSQL hostname for application JDBC connections."
  value       = aws_db_instance.application.address
}

output "rds_port" {
  description = "PostgreSQL TCP port."
  value       = aws_db_instance.application.port
}

output "rds_admin_secret_arn" {
  description = "ARN of the RDS-managed admin secret; does not expose the password."
  value       = aws_db_instance.application.master_user_secret[0].secret_arn
}

output "ecr_repository_url" {
  description = "PetClinic image repository URL shared by staging and production."
  value       = aws_ecr_repository.petclinic.repository_url
}

output "github_actions_role_arn" {
  description = "Role ARN for GitHub Actions OIDC authentication from this repository's main branch."
  value       = aws_iam_role.github_actions.arn
}
