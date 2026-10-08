# Attach the internet gateway to the VPC.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.vpc_8byte_ai.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Both public subnets use this table.
# AWS automatically includes a local route for traffic inside the VPC.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc_8byte_ai.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# IPv4 traffic outside the VPC can reach the internet gateway.
# Keep routes as separate resources rather than mixing inline and standalone routes.
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Separate private tables let subnet A use NAT while subnet B stays local-only.
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.vpc_8byte_ai.id

  tags = {
    Name = "${var.project_name}-private-a-rt"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.vpc_8byte_ai.id

  tags = {
    Name = "${var.project_name}-private-b-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# Outbound IPv4 access for the planned private EC2 host in subnet A.
# The VPC's more specific local route still handles EC2-to-RDS traffic.
resource "aws_route" "private_a_internet" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}
