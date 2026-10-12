# One public IPv4 address for outbound connections through the NAT gateway.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# Keep NAT and the planned EC2 in Availability Zone A to avoid cross-AZ traffic.
resource "aws_nat_gateway" "main" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = aws_subnet.public_a.id
  connectivity_type = "public"
  availability_mode = "zonal"

  # The public subnet must have its internet route before NAT is used.
  depends_on = [
    aws_internet_gateway.main,
    aws_route.public_internet,
    aws_route_table_association.public_a,
  ]

  tags = {
    Name = "${var.project_name}-nat-a"
  }
}
