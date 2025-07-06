# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de duas VPCs, o estabelecimento de uma conexão
# de VPC Peering entre elas e a configuração das tabelas de rotas para permitir
# a comunicação privada entre as instâncias nas VPCs.

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

# --- VPC A (Requester) ---
resource "aws_vpc" "vpc_a" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "VPC-Dev"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "VPC-Dev-Subnet"
  }
}

resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id

  tags = {
    Name = "VPC-Dev-IGW"
  }
}

resource "aws_route_table" "rt_a" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }

  tags = {
    Name = "VPC-Dev-RT"
  }
}

resource "aws_route_table_association" "rt_a_association" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt_a.id
}

# --- VPC B (Accepter) ---
resource "aws_vpc" "vpc_b" {
  cidr_block = "10.20.0.0/16"

  tags = {
    Name = "VPC-Data"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "VPC-Data-Subnet"
  }
}

resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id

  tags = {
    Name = "VPC-Data-IGW"
  }
}

resource "aws_route_table" "rt_b" {
  vpc_id = aws_vpc.vpc_b.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_b.id
  }

  tags = {
    Name = "VPC-Data-RT"
  }
}

resource "aws_route_table_association" "rt_b_association" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt_b.id
}

# --- Conexão de VPC Peering ---
resource "aws_vpc_peering_connection" "dev_data_peering" {
  vpc_id      = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true # Define como true para aceitar automaticamente se for na mesma conta

  tags = {
    Name = "Dev-to-Data-Peering"
  }
}

# --- Atualizar Tabelas de Rotas para Peering ---
# Rota na VPC A para VPC B
resource "aws_route" "vpc_a_to_vpc_b" {
  route_table_id            = aws_route_table.rt_a.id
  destination_cidr_block    = aws_vpc.vpc_b.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_data_peering.id
}

# Rota na VPC B para VPC A
resource "aws_route" "vpc_b_to_vpc_a" {
  route_table_id            = aws_route_table.rt_b.id
  destination_cidr_block    = aws_vpc.vpc_a.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_data_peering.id
}

# --- Security Groups (Exemplo de atualização para permitir tráfego via peering) ---
# Nota: Em um cenário real, você associaria esses SGs às suas instâncias EC2.
# Aqui, estamos apenas criando-os para demonstrar como as regras seriam configuradas.

resource "aws_security_group" "sg_a" {
  name        = "VPC-Dev-SG"
  description = "Allow SSH and ICMP from VPC-Data"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_b.cidr_block] # Permite SSH da VPC B
  }

  ingress {
    from_port   = -1 # ICMP
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_b.cidr_block] # Permite Ping da VPC B
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_b" {
  name        = "VPC-Data-SG"
  description = "Allow SSH and ICMP from VPC-Dev"
  vpc_id      = aws_vpc.vpc_b.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block] # Permite SSH da VPC A
  }

  ingress {
    from_port   = -1 # ICMP
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block] # Permite Ping da VPC A
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Saídas (Outputs) para facilitar a referência e verificação
output "vpc_a_id" {
  description = "The ID of VPC A (Requester)"
  value       = aws_vpc.vpc_a.id
}

output "vpc_b_id" {
  description = "The ID of VPC B (Accepter)"
  value       = aws_vpc.vpc_b.id
}

output "peering_connection_id" {
  description = "The ID of the VPC Peering Connection"
  value       = aws_vpc_peering_connection.dev_data_peering.id
}

output "vpc_a_subnet_id" {
  description = "The ID of VPC A's subnet"
  value       = aws_subnet.subnet_a.id
}

output "vpc_b_subnet_id" {
  description = "The ID of VPC B's subnet"
  value       = aws_subnet.subnet_b.id
}