resource "aws_vpc" "shared_services_vpc" {
  cidr_block = "10.100.0.0/16"

  tags = {
    Name = "SharedServicesVPC"
  }
}

# Exemplo de como conectar outras VPCs à Shared Services VPC usando VPC Peering
resource "aws_vpc_peering_connection" "app_to_shared_services" {
  vpc_id        = aws_vpc.custom_vpc.id
  peer_vpc_id   = aws_vpc.shared_services_vpc.id
  auto_accept   = true

  tags = {
    Side = "AppToSharedServices"
  }
}
