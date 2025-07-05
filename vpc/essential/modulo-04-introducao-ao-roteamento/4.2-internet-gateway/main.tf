# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um Internet Gateway (IGW) e sua integração
# com uma VPC e uma sub-rede pública, permitindo a conectividade com a internet.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.lab_vpc').
# - Uma sub-rede pública existente (referenciada como 'aws_subnet.lab_public_subnet').
# - Uma tabela de rotas pública existente (referenciada como 'aws_route_table.lab_public_rt').

# Exemplo de como você pode referenciar a VPC, subnets e route tables
# se eles foram criados em outro lugar ou em um módulo anterior.
# resource "aws_vpc" "lab_vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = { Name = "Lab-VPC-IGW" }
# }

# resource "aws_subnet" "lab_public_subnet" {
#   vpc_id                  = aws_vpc.lab_vpc.id
#   cidr_block              = "10.0.1.0/24"
#   availability_zone       = "us-east-1a"
#   map_public_ip_on_launch = true
#   tags = { Name = "Lab-Public-Subnet-IGW" }
# }

# resource "aws_route_table" "lab_public_rt" {
#   vpc_id = aws_vpc.lab_vpc.id
#   tags = { Name = "Lab-Public-RT-IGW" }
# }

# 1. Recurso: Internet Gateway
# Cria um Internet Gateway e o anexa à VPC.
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "Lab-IGW"
  }
}

# 2. Recurso: Rota Padrão para a Internet
# Adiciona uma rota para todo o tráfego (0.0.0.0/0) na tabela de rotas pública,
# direcionando-o para o Internet Gateway.
resource "aws_route" "internet_access_route" {
  route_table_id         = aws_route_table.lab_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab_igw.id

  # Garante que o IGW exista antes de criar a rota
  depends_on = [aws_internet_gateway.lab_igw]
}

# 3. Recurso: Associação da Tabela de Rotas à Sub-rede Pública
# Associa a tabela de rotas pública (que agora tem a rota para o IGW) à sub-rede pública.
resource "aws_route_table_association" "lab_public_subnet_association" {
  subnet_id      = aws_subnet.lab_public_subnet.id
  route_table_id = aws_route_table.lab_public_rt.id

  # Garante que a rota para o IGW exista antes de associar a tabela
  depends_on = [aws_route.internet_access_route]
}

# Saídas (Outputs) para facilitar a verificação
output "internet_gateway_id" {
  description = "The ID of the created Internet Gateway"
  value       = aws_internet_gateway.lab_igw.id
}