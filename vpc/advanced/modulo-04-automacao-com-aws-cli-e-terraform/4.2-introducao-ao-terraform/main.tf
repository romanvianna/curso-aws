# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de uma VPC básica com uma sub-rede pública,
# Internet Gateway e tabela de rotas associada, utilizando a abordagem declarativa do Terraform.

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

# 1. Declaração de um recurso: uma VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block = "10.200.0.0/16"

  tags = {
    Name        = "Terraform-Lab-VPC"
    Environment = "Development"
  }
}

# 2. Declaração de outro recurso: uma sub-rede pública
resource "aws_subnet" "lab_public_subnet" {
  # Referência a um atributo de outro recurso (vpc_id).
  # O Terraform entende essa dependência implicitamente e criará a VPC primeiro.
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.200.1.0/24"
  availability_zone       = "us-east-1a" # Escolha uma AZ na sua região
  map_public_ip_on_launch = true # Habilita auto-assign de IPs públicos

  tags = {
    Name = "Terraform-Lab-Public-Subnet"
  }
}

# 3. Declaração de um Internet Gateway
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "Terraform-Lab-IGW"
  }
}

# 4. Declaração de uma Tabela de Rotas Pública
resource "aws_route_table" "lab_public_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }

  tags = {
    Name = "Terraform-Lab-Public-RT"
  }
}

# 5. Associação da Tabela de Rotas à Sub-rede Pública
resource "aws_route_table_association" "lab_public_subnet_association" {
  subnet_id      = aws_subnet.lab_public_subnet.id
  route_table_id = aws_route_table.lab_public_rt.id
}

# Declaração de valores de saída (outputs)
# Estes valores podem ser usados por outros módulos ou para verificação.
output "vpc_id" {
  description = "The ID of the VPC created by Terraform"
  value       = aws_vpc.lab_vpc.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet created by Terraform"
  value       = aws_subnet.lab_public_subnet.id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway created by Terraform"
  value       = aws_internet_gateway.lab_igw.id
}