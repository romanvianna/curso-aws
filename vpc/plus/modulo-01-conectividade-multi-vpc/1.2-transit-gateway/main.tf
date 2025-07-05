resource "aws_ec2_transit_gateway" "example" {
  description = "My Transit Gateway"
  tags = {
    Name = "MyTransitGateway"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "example" {
  vpc_id             = aws_vpc.custom_vpc.id
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  subnet_ids         = [aws_subnet.public_subnet.id]
}
