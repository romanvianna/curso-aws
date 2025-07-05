# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de uma VPC customizada com sub-redes públicas
# e privadas, um Internet Gateway e tabelas de rotas associadas. O objetivo é
# solidificar o entendimento dos componentes da VPC e como eles se interligam.

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
resource "aws_vpc" "lab_vpc" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "Essential-Custom-VPC"
  }
}

# 2. Recurso: Internet Gateway
# Permite a comunicação entre a VPC e a internet.
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "Essential-Lab-IGW"
  }
}

# 3. Recurso: Sub-rede Pública
# Uma sub-rede dentro da VPC, localizada em uma Zona de Disponibilidade.
# 'map_public_ip_on_launch' habilita a atribuição automática de IPs públicos
# para instâncias lançadas nesta sub-rede.
resource "aws_subnet" "lab_public_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a" # Escolha uma AZ na sua região
  map_public_ip_on_launch = true

  tags = {
    Name = "Essential-Lab-Public-Subnet"
  }
}

# 4. Recurso: Sub-rede Privada
# Uma sub-rede dentro da VPC, localizada em uma Zona de Disponibilidade.
# Não possui auto-assign de IPs públicos, mantendo-a isolada da internet.
resource "aws_subnet" "lab_private_subnet" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "us-east-1a" # Escolha a mesma AZ da sub-rede pública para simplicidade

  tags = {
    Name = "Essential-Lab-Private-Subnet"
  }
}

# 5. Recurso: Tabela de Rotas Pública
# Define as regras de roteamento para a sub-rede pública, direcionando o tráfego
# para a internet via Internet Gateway.
resource "aws_route_table" "lab_public_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  # Rota padrão para a internet via Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }

  tags = {
    Name = "Essential-Lab-Public-RT"
  }
}

# 6. Recurso: Associação da Tabela de Rotas Pública à Sub-rede Pública
# Associa a tabela de rotas pública à sub-rede pública.
resource "aws_route_table_association" "lab_public_subnet_association" {
  subnet_id      = aws_subnet.lab_public_subnet.id
  route_table_id = aws_route_table.lab_public_rt.id
}

# 7. Recurso: Tabela de Rotas Privada
# Define as regras de roteamento para a sub-rede privada. Por padrão, apenas
# a rota local é necessária, mantendo-a isolada da internet.
resource "aws_route_table" "lab_private_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "Essential-Lab-Private-RT"
  }
}

# 8. Recurso: Associação da Tabela de Rotas Privada à Sub-rede Privada
# Associa a tabela de rotas privada à sub-rede privada.
resource "aws_route_table_association" "lab_private_subnet_association" {
  subnet_id      = aws_subnet.lab_private_subnet.id
  route_table_id = aws_route_table.lab_private_rt.id
}

# Saídas (Outputs) para facilitar a verificação no console ou em outros módulos
output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.lab_vpc.id
}

output "public_subnet_id" {
  description = "The ID of the created public subnet"
  value       = aws_subnet.lab_public_subnet.id
}

output "private_subnet_id" {
  description = "The ID of the created private subnet"
  value       = aws_subnet.lab_private_subnet.id
}

output "internet_gateway_id" {
  description = "The ID of the created Internet Gateway"
  value       = aws_internet_gateway.lab_igw.id
}

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.lab_public_rt.id
}

output "private_route_table_id" {
  description = "The ID of the private route table"
  value       = aws_route_table.lab_private_rt.id
}