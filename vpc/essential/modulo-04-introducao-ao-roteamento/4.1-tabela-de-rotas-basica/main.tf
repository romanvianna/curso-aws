# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de uma VPC com sub-redes públicas e privadas,
# um Internet Gateway e a configuração de tabelas de rotas para controlar o fluxo
# de tráfego, ilustrando o conceito de roteamento básico e a lógica de "longest prefix match".

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

# 1. Recurso: VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Lab-VPC-Routing"
  }
}

# 2. Recurso: Internet Gateway
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "Lab-IGW-Routing"
  }
}

# 3. Recurso: Sub-rede Pública
resource "aws_subnet" "lab_public_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a" # Escolha uma AZ na sua região
  map_public_ip_on_launch = true

  tags = {
    Name = "Lab-Public-Subnet-Routing"
  }
}

# 4. Recurso: Sub-rede Privada
resource "aws_subnet" "lab_private_subnet" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a" # Escolha a mesma AZ da pública para simplicidade

  tags = {
    Name = "Lab-Private-Subnet-Routing"
  }
}

# 5. Recurso: Tabela de Rotas Pública Customizada
# Esta tabela de rotas terá uma rota para o Internet Gateway, tornando a sub-rede pública.
resource "aws_route_table" "lab_public_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }

  tags = {
    Name = "Lab-Public-RT-Routing"
  }
}

# 6. Recurso: Associação da Tabela de Rotas Pública à Sub-rede Pública
resource "aws_route_table_association" "lab_public_subnet_association" {
  subnet_id      = aws_subnet.lab_public_subnet.id
  route_table_id = aws_route_table.lab_public_rt.id
}

# 7. Data Source: Obtendo a Tabela de Rotas Principal da VPC
# A sub-rede privada será associada implicitamente a esta tabela, que por padrão
# só contém a rota local, mantendo a sub-rede privada isolada da internet.
data "aws_route_table" "lab_main_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  main   = true
}

# Saídas (Outputs) para facilitar a verificação no console ou em outros módulos
output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.lab_vpc.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.lab_public_subnet.id
}

output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.lab_private_subnet.id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.lab_igw.id
}

output "public_route_table_id" {
  description = "The ID of the public custom route table"
  value       = aws_route_table.lab_public_rt.id
}

output "main_route_table_id" {
  description = "The ID of the main route table (associated with private subnet)"
  value       = data.aws_route_table.lab_main_rt.id
}