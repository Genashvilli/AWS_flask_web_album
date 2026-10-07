resource "aws_subnet" "extra" {
  vpc_id                  = data.aws_vpc.default.id
  availability_zone       = local.second_az
  cidr_block              = var.extra_subnet_cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-extra-subnet"
  }
}

resource "aws_route_table_association" "extra" {
  subnet_id      = aws_subnet.extra.id
  route_table_id = data.aws_route_tables.default.ids[0]
}