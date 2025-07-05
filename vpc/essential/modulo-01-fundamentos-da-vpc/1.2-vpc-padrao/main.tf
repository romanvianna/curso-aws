# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra como interagir com a VPC Padrão (Default VPC)
# usando Terraform. A Default VPC é criada automaticamente pela AWS em cada região.
# O Terraform é usado para gerenciar recursos, não para criar a Default VPC em si.

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

# 1. Data Source: Obtendo informações da Default VPC existente
# Este bloco 'data' permite que o Terraform leia informações sobre uma VPC
# que já existe na sua conta AWS, sem gerenciá-la diretamente.
data "aws_vpc" "default" {
  default = true
}

# Saídas (Outputs) para exibir informações da Default VPC
output "default_vpc_id" {
  description = "The ID of the Default VPC"
  value       = data.aws_vpc.default.id
}

output "default_vpc_cidr_block" {
  description = "The CIDR block of the Default VPC"
  value       = data.aws_vpc.default.cidr_block
}

output "default_vpc_main_route_table_id" {
  description = "The ID of the main route table of the Default VPC"
  value       = data.aws_vpc.default.main_route_table_id
}

# --- Exemplo Opcional: Criando uma VPC Customizada que pode ser usada como base para labs ---
# Este bloco demonstra como você criaria uma VPC do zero, que é a prática recomendada
# para ambientes de produção, em vez de usar a Default VPC.
# Descomente para usar e lembre-se de que esta NÃO é a Default VPC da AWS.

/*
resource "aws_vpc" "custom_lab_vpc" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "Custom-Lab-VPC"
  }
}

resource "aws_subnet" "custom_lab_public_subnet" {
  vpc_id                  = aws_vpc.custom_lab_vpc.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Custom-Lab-Public-Subnet"
  }
}

resource "aws_internet_gateway" "custom_lab_igw" {
  vpc_id = aws_vpc.custom_lab_vpc.id

  tags = {
    Name = "Custom-Lab-IGW"
  }
}

resource "aws_route_table" "custom_lab_public_rt" {
  vpc_id = aws_vpc.custom_lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom_lab_igw.id
  }

  tags = {
    Name = "Custom-Lab-Public-RT"
  }
}

resource "aws_route_table_association" "custom_lab_public_subnet_association" {
  subnet_id      = aws_subnet.custom_lab_public_subnet.id
  route_table_id = aws_route_table.custom_lab_public_rt.id
}

output "custom_lab_vpc_id" {
  description = "The ID of the custom lab VPC"
  value       = aws_vpc.custom_lab_vpc.id
}
*/