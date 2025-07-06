# --- Exemplo de provisionamento via Terraform para Otimização de Custos ---

# Este arquivo demonstra como provisionar recursos de rede na AWS de forma a otimizar custos,
# especificamente focando na redução de custos de transferência de dados para o Amazon S3
# utilizando um VPC Gateway Endpoint, contornando o NAT Gateway.

# Bloco de configuração do Terraform para especificar o provedor AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a versão mais recente compatível
    }
  }
}

# Configuração do provedor AWS
provider "aws" {
  region = "us-east-1" # Defina a região da AWS
}

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.lab_vpc').
# - Uma sub-rede pública existente (referenciada como 'aws_subnet.lab_public_subnet').
# - Uma sub-rede privada existente (referenciada como 'aws_subnet.lab_private_subnet').
# - Uma tabela de rotas privada existente (referenciada como 'aws_route_table.lab_private_rt').

# Exemplo de como você pode referenciar a VPC, subnets e route tables
# se eles foram criados em outro lugar ou em um módulo anterior.
# resource "aws_vpc" "lab_vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = { Name = "Cost-Opt-VPC" }
# }

# resource "aws_subnet" "lab_public_subnet" {
#   vpc_id                  = aws_vpc.lab_vpc.id
#   cidr_block              = "10.0.1.0/24"
#   availability_zone       = "us-east-1a"
#   map_public_ip_on_launch = true
#   tags = { Name = "Cost-Opt-Public-Subnet" }
# }

# resource "aws_subnet" "lab_private_subnet" {
#   vpc_id            = aws_vpc.lab_vpc.id
#   cidr_block        = "10.0.2.0/24"
#   availability_zone = "us-east-1a"
#   tags = { Name = "Cost-Opt-Private-Subnet" }
# }

# resource "aws_route_table" "lab_private_rt" {
#   vpc_id = aws_vpc.lab_vpc.id
#   tags = { Name = "Cost-Opt-Private-RT" }
# }

# --- 1. Criação de um NAT Gateway (para simular o cenário antes da otimização) ---
# Este NAT Gateway seria o caminho padrão para o tráfego de saída da sub-rede privada.
resource "aws_eip" "nat_gateway_eip" {
  vpc = true

  tags = {
    Name = "Cost-Opt-NAT-GW-EIP"
  }
}

resource "aws_nat_gateway" "lab_nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.lab_public_subnet.id

  tags = {
    Name = "Cost-Opt-NAT-Gateway"
  }
}

# Adiciona uma rota padrão para o NAT Gateway na tabela de rotas privada
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.lab_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.lab_nat_gateway.id

  depends_on = [aws_nat_gateway.lab_nat_gateway]
}

# --- 2. Criação de um VPC Gateway Endpoint para S3 (Otimização de Custos) ---
# Este endpoint permite que o tráfego para o S3 da sub-rede privada
# contorne o NAT Gateway, resultando em economia de custos e maior segurança.
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id       = aws_vpc.lab_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3" # Nome do serviço S3 na região
  vpc_endpoint_type = "Gateway" # Tipo Gateway para S3 e DynamoDB

  # Associa o endpoint à tabela de rotas da sub-rede privada.
  # O Terraform adicionará automaticamente a rota para o prefix list do S3.
  route_table_ids = [aws_route_table.lab_private_rt.id]

  tags = {
    Name = "Cost-Opt-S3-Gateway-Endpoint"
  }

  # Garante que a rota para o NAT Gateway exista antes de criar o endpoint
  # para que a nova rota para o S3 seja mais específica e tenha precedência.
  depends_on = [aws_route.private_nat_route]
}

# Saídas (Outputs) para facilitar a verificação
output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.lab_nat_gateway.id
}

output "s3_gateway_endpoint_id" {
  description = "The ID of the S3 Gateway Endpoint"
  value       = aws_vpc_endpoint.s3_gateway_endpoint.id
}

output "s3_gateway_endpoint_route_table_id" {
  description = "The ID of the route table associated with the S3 Gateway Endpoint"
  value       = aws_route_table.lab_private_rt.id
}