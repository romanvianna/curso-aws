# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um Transit Gateway (TGW) e a conexão
# de três VPCs a ele, permitindo a comunicação entre elas de forma escalável
# e seguindo o modelo Hub-and-Spoke.

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

# --- 1. Criação das VPCs (Spokes) ---

# VPC A (Desenvolvimento)
resource "aws_vpc" "vpc_dev" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "VPC-Dev-TGW"
  }
}

resource "aws_subnet" "subnet_dev" {
  vpc_id                  = aws_vpc.vpc_dev.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "VPC-Dev-Subnet"
  }
}

resource "aws_route_table" "rt_dev" {
  vpc_id = aws_vpc.vpc_dev.id

  tags = {
    Name = "VPC-Dev-RT"
  }
}

resource "aws_route_table_association" "rt_dev_association" {
  subnet_id      = aws_subnet.subnet_dev.id
  route_table_id = aws_route_table.rt_dev.id
}

# VPC B (Teste)
resource "aws_vpc" "vpc_test" {
  cidr_block = "10.20.0.0/16"

  tags = {
    Name = "VPC-Test-TGW"
  }
}

resource "aws_subnet" "subnet_test" {
  vpc_id                  = aws_vpc.vpc_test.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "VPC-Test-Subnet"
  }
}

resource "aws_route_table" "rt_test" {
  vpc_id = aws_vpc.vpc_test.id

  tags = {
    Name = "VPC-Test-RT"
  }
}

resource "aws_route_table_association" "rt_test_association" {
  subnet_id      = aws_subnet.subnet_test.id
  route_table_id = aws_route_table.rt_test.id
}

# VPC C (Produção)
resource "aws_vpc" "vpc_prod" {
  cidr_block = "10.30.0.0/16"

  tags = {
    Name = "VPC-Prod-TGW"
  }
}

resource "aws_subnet" "subnet_prod" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "10.30.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "VPC-Prod-Subnet"
  }
}

resource "aws_route_table" "rt_prod" {
  vpc_id = aws_vpc.vpc_prod.id

  tags = {
    Name = "VPC-Prod-RT"
  }
}

resource "aws_route_table_association" "rt_prod_association" {
  subnet_id      = aws_subnet.subnet_prod.id
  route_table_id = aws_route_table.rt_prod.id
}

# --- 2. Criação do Transit Gateway (Hub) ---
resource "aws_ec2_transit_gateway" "lab_tgw" {
  description = "Lab Transit Gateway"

  tags = {
    Name = "Lab-TGW"
  }
}

# --- 3. Anexos das VPCs ao TGW ---
resource "aws_ec2_transit_gateway_vpc_attachment" "attach_dev" {
  vpc_id             = aws_vpc.vpc_dev.id
  transit_gateway_id = aws_ec2_transit_gateway.lab_tgw.id
  subnet_ids         = [aws_subnet.subnet_dev.id]

  tags = {
    Name = "TGW-Attach-VPC-Dev"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attach_test" {
  vpc_id             = aws_vpc.vpc_test.id
  transit_gateway_id = aws_ec2_transit_gateway.lab_tgw.id
  subnet_ids         = [aws_subnet.subnet_test.id]

  tags = {
    Name = "TGW-Attach-VPC-Test"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attach_prod" {
  vpc_id             = aws_vpc.vpc_prod.id
  transit_gateway_id = aws_ec2_transit_gateway.lab_tgw.id
  subnet_ids         = [aws_subnet.subnet_prod.id]

  tags = {
    Name = "TGW-Attach-VPC-Prod"
  }
}

# --- 4. Rotas nas Tabelas de Rotas das VPCs para o TGW ---
# Cada VPC precisa de rotas para as outras VPCs, apontando para o TGW.

# Rotas na VPC Dev (rt_dev)
resource "aws_route" "dev_to_test" {
  route_table_id         = aws_route_table.rt_dev.id
  destination_cidr_block = aws_vpc.vpc_test.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.lab_tgw.id
}

resource "aws_route" "dev_to_prod" {
  route_table_id         = aws_route_table.rt_dev.id
  destination_cidr_block = aws_vpc.vpc_prod.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.lab_tgw.id
}

# Rotas na VPC Test (rt_test)
resource "aws_route" "test_to_dev" {
  route_table_id         = aws_route_table.rt_test.id
  destination_cidr_block = aws_vpc.vpc_dev.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.lab_tgw.id
}

resource "aws_route" "test_to_prod" {
  route_table_id         = aws_route_table.rt_test.id
  destination_cidr_block = aws_vpc.vpc_prod.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.lab_tgw.id
}

# Rotas na VPC Prod (rt_prod)
resource "aws_route" "prod_to_dev" {
  route_table_id         = aws_route_table.rt_prod.id
  destination_cidr_block = aws_vpc.vpc_dev.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.lab_tgw.id
}

resource "aws_route" "prod_to_test" {
  route_table_id         = aws_route_table.rt_prod.id
  destination_cidr_block = aws_vpc.vpc_test.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.lab_tgw.id
}

# Saídas (Outputs) para facilitar a referência e verificação
output "tgw_id" {
  description = "The ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.lab_tgw.id
}

output "vpc_dev_id" {
  description = "The ID of the Development VPC"
  value       = aws_vpc.vpc_dev.id
}

output "vpc_test_id" {
  description = "The ID of the Test VPC"
  value       = aws_vpc.vpc_test.id
}

output "vpc_prod_id" {
  description = "The ID of the Production VPC"
  value       = aws_vpc.vpc_prod.id
}