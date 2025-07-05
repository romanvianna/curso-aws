resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.custom_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.r.id]
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = aws_vpc.custom_vpc.id
  service_name      = "com.amazonaws.us-east-1.ec2"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_subnet.id]
  security_group_ids = [aws_security_group.allow_ssh.id]
}
