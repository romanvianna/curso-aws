# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de uma VPC básica com uma sub-rede pública
# e um Internet Gateway. O objetivo deste módulo é entender os componentes
# de uma VPC, e este código serve como um exemplo simples para visualização
# no console da AWS após a aplicação.

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
# Cria uma Virtual Private Cloud com um bloco CIDR específico.
resource "aws_vpc" "basic_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Basic-Lab-VPC"
  }
}

# 2. Recurso: Internet Gateway
# Permite a comunicação entre a VPC e a internet.
resource "aws_internet_gateway" "basic_igw" {
  vpc_id = aws_vpc.basic_vpc.id

  tags = {
    Name = "Basic-Lab-IGW"
  }
}

# 3. Recurso: Sub-rede Pública
# Uma sub-rede dentro da VPC, localizada em uma Zona de Disponibilidade.
# 'map_public_ip_on_launch' habilita a atribuição automática de IPs públicos
# para instâncias lançadas nesta sub-rede.
resource "aws_subnet" "basic_public_subnet" {
  vpc_id                  = aws_vpc.basic_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a" # Escolha uma AZ na sua região
  map_public_ip_on_launch = true

  tags = {
    Name = "Basic-Lab-Public-Subnet"
  }
}

# 4. Recurso: Tabela de Rotas Pública
# Define as regras de roteamento para a sub-rede pública.
resource "aws_route_table" "basic_public_rt" {
  vpc_id = aws_vpc.basic_vpc.id

  # Rota padrão para a internet via Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.basic_igw.id
  }

  tags = {
    Name = "Basic-Lab-Public-RT"
  }
}

# 5. Recurso: Associação da Tabela de Rotas à Sub-rede
# Associa a tabela de rotas pública à sub-rede pública.
resource "aws_route_table_association" "basic_public_subnet_association" {
  subnet_id      = aws_subnet.basic_public_subnet.id
  route_table_id = aws_route_table.basic_public_rt.id
}

# Saídas (Outputs) para facilitar a verificação no console ou em outros módulos
output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.basic_vpc.id
}

output "public_subnet_id" {
  description = "The ID of the created public subnet"
  value       = aws_subnet.basic_public_subnet.id
}

output "internet_gateway_id" {
  description = "The ID of the created Internet Gateway"
  value       = aws_internet_gateway.basic_igw.id
}