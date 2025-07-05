# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um NAT Gateway e a configuração de roteamento
# para permitir que instâncias em uma sub-rede privada acessem a internet.

# Pré-requisitos:
# - Uma VPC existente (referenciada aqui como 'aws_vpc.custom_vpc').
# - Uma sub-rede pública existente (referenciada aqui como 'aws_subnet.public_subnet').
# - Uma sub-rede privada existente (referenciada aqui como 'aws_subnet.private_subnet').
# - Uma tabela de rotas associada à sub-rede privada (referenciada aqui como 'aws_route_table.private_route_table').

# Exemplo de como você poderia definir a VPC e as sub-redes em um arquivo separado
# ou em um módulo, se não estiverem já definidas.
# resource "aws_vpc" "custom_vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = { Name = "LabVPC" }
# }

# resource "aws_subnet" "public_subnet" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.1.0/24"
#   availability_zone = "us-east-1a" # Substitua pela AZ da sua região
#   map_public_ip_on_launch = true
#   tags = { Name = "LabPublicSubnet" }
# }

# resource "aws_subnet" "private_subnet" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.2.0/24"
#   availability_zone = "us-east-1a" # Substitua pela AZ da sua região
#   tags = { Name = "LabPrivateSubnet" }
# }

# resource "aws_route_table" "private_route_table" {
#   vpc_id = aws_vpc.custom_vpc.id
#   tags = { Name = "LabPrivateRouteTable" }
# }

# resource "aws_route_table_association" "private_subnet_association" {
#   subnet_id      = aws_subnet.private_subnet.id
#   route_table_id = aws_route_table.private_route_table.id
# }

# 1. Aloca um Elastic IP (EIP) para o NAT Gateway
# Este EIP será o endereço público que o NAT Gateway usará para se comunicar com a internet.
resource "aws_eip" "nat_gateway_eip" {
  vpc = true # Indica que o EIP será usado dentro de uma VPC
  tags = {
    Name = "LabNATGatewayEIP"
  }
}

# 2. Cria o NAT Gateway
# O NAT Gateway deve ser provisionado em uma sub-rede pública, pois ele precisa de acesso ao Internet Gateway.
resource "aws_nat_gateway" "lab_nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id # Associa o EIP alocado
  subnet_id     = aws_subnet.public_subnet.id # ID da sub-rede pública onde o NAT GW será criado

  tags = {
    Name = "LabNATGateway"
  }
  # Depende implicitamente da criação do EIP e da sub-rede pública.
}

# 3. Adiciona uma rota na tabela de rotas da sub-rede privada
# Esta rota direciona todo o tráfego de saída (0.0.0.0/0) da sub-rede privada para o NAT Gateway.
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_route_table.id # ID da tabela de rotas da sub-rede privada
  destination_cidr_block = "0.0.0.0/0" # Destino para todo o tráfego de internet
  nat_gateway_id         = aws_nat_gateway.lab_nat_gateway.id # O NAT Gateway como alvo

  # Depende implicitamente da criação do NAT Gateway e da tabela de rotas privada.
}

# Saídas (Outputs) para facilitar a referência em outros módulos ou para verificação
output "nat_gateway_id" {
  description = "The ID of the created NAT Gateway"
  value       = aws_nat_gateway.lab_nat_gateway.id
}

output "nat_gateway_eip_public_ip" {
  description = "The public IP address of the NAT Gateway"
  value       = aws_eip.nat_gateway_eip.public_ip
}