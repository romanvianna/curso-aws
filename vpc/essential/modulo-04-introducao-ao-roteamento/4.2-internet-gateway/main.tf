resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.r.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}
