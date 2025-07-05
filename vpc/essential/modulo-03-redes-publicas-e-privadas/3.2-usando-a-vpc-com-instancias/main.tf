# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um NAT Gateway e a configuração de roteamento
# para permitir que instâncias em uma sub-rede privada acessem a internet.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.lab_vpc').
# - Uma sub-rede pública existente (referenciada como 'aws_subnet.lab_public_subnet').
# - Uma sub-rede privada existente (referenciada como 'aws_subnet.lab_private_subnet').
# - Uma tabela de rotas associada à sub-rede privada (referenciada como 'aws_route_table.lab_private_rt').

# Exemplo de como você poderia definir a VPC, subnets e route tables
# se eles foram criados em outro lugar ou em um módulo anterior.
# resource "aws_vpc" "lab_vpc" {
#   cidr_block = "10.10.0.0/16"
#   tags = { Name = "Essential-Custom-VPC" }
# }

# resource "aws_subnet" "lab_public_subnet" {
#   vpc_id                  = aws_vpc.lab_vpc.id
#   cidr_block              = "10.10.1.0/24"
#   availability_zone       = "us-east-1a"
#   map_public_ip_on_launch = true
#   tags = { Name = "Essential-Lab-Public-Subnet" }
# }

# resource "aws_subnet" "lab_private_subnet" {
#   vpc_id            = aws_vpc.lab_vpc.id
#   cidr_block        = "10.10.2.0/24"
#   availability_zone = "us-east-1a"
#   tags = { Name = "Essential-Lab-Private-Subnet" }
# }

# resource "aws_route_table" "lab_private_rt" {
#   vpc_id = aws_vpc.lab_vpc.id
#   tags = { Name = "Essential-Lab-Private-RT" }
# }

# 1. Aloca um Elastic IP (EIP) para o NAT Gateway
# Este EIP será o endereço público que o NAT Gateway usará para se comunicar com a internet.
resource "aws_eip" "nat_gateway_eip" {
  vpc = true # Indica que o EIP será usado dentro de uma VPC
  tags = {
    Name = "Lab-NAT-GW-EIP"
  }
}

# 2. Cria o NAT Gateway
# O NAT Gateway deve ser provisionado em uma sub-rede pública, pois ele precisa de acesso ao Internet Gateway.
resource "aws_nat_gateway" "lab_nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id # Associa o EIP alocado
  subnet_id     = aws_subnet.lab_public_subnet.id # ID da sub-rede pública onde o NAT GW será criado

  tags = {
    Name = "Lab-NAT-Gateway"
  }

  # Garante que o EIP e a sub-rede pública existam antes de criar o NAT Gateway
  depends_on = [aws_eip.nat_gateway_eip, aws_subnet.lab_public_subnet]
}

# 3. Adiciona uma rota na tabela de rotas da sub-rede privada
# Esta rota direciona todo o tráfego de saída (0.0.0.0/0) da sub-rede privada para o NAT Gateway.
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.lab_private_rt.id # ID da tabela de rotas da sub-rede privada
  destination_cidr_block = "0.0.0.0/0" # Destino para todo o tráfego de internet
  nat_gateway_id         = aws_nat_gateway.lab_nat_gateway.id # O NAT Gateway como alvo

  # Garante que o NAT Gateway e a tabela de rotas privada existam antes de adicionar a rota
  depends_on = [aws_nat_gateway.lab_nat_gateway, aws_route_table.lab_private_rt]
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