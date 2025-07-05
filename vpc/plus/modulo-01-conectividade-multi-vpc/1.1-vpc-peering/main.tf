resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = aws_vpc.custom_vpc.id
  peer_vpc_id   = aws_vpc.terraform_vpc.id
  auto_accept   = true

  tags = {
    Side  = "Requester"
  }
}

resource "aws_route" "peer_route_requester" {
  route_table_id            = aws_route_table.r.id
  destination_cidr_block    = aws_vpc.terraform_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "peer_route_accepter" {
  route_table_id            = aws_route_table.r.id # Assuming a route table for the peer VPC
  destination_cidr_block    = aws_vpc.custom_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}
