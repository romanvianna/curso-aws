resource "aws_customer_gateway" "main" {
  bgp_asn    = "65000"
  ip_address = "203.0.113.12"
  type       = "ipsec.1"

  tags = {
    Name = "MainCustomerGateway"
  }
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "MainVpnGateway"
  }
}

resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.main.id
  type                = "ipsec.1"

  static_routes_only = true

  static_routes_config {
    destination_cidr_blocks = ["172.16.0.0/16"]
  }
}
