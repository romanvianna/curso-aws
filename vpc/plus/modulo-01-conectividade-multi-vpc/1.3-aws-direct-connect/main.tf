# O AWS Direct Connect envolve um processo físico e não é totalmente automatizável via Terraform para a etapa inicial de provisionamento da conexão física. No entanto, você pode gerenciar as Virtual Interfaces (VIFs) e gateways associados.

resource "aws_dx_gateway" "example" {
  name            = "my-dx-gateway"
  amazon_side_asn = "64512"
}

resource "aws_dx_private_virtual_interface" "example" {
  connection_id    = "dxcon-abcdefgh"
  name             = "my-private-vif"
  vlan             = 4094
  address_family   = "ipv4"
  bgp_asn          = 65350
  vpc_id           = aws_vpc.custom_vpc.id
  dx_gateway_id    = aws_dx_gateway.example.id
}
