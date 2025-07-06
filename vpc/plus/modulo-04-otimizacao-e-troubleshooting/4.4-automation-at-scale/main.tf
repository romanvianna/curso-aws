# --- Exemplo de provisionamento via Terraform para Automação em Escala com GitOps ---

# Este arquivo contém uma configuração Terraform simples que seria gerenciada
# por um pipeline de CI/CD (GitOps). O objetivo é demonstrar como as alterações
# no código Git se traduzem em alterações na infraestrutura da AWS de forma automatizada.

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
# Esta VPC será o recurso de exemplo gerenciado pelo pipeline GitOps.
resource "aws_vpc" "gitops_demo_vpc" {
  cidr_block = "10.60.0.0/16"

  tags = {
    Name        = "GitOps-Demo-VPC"
    Environment = "Development"
    ManagedBy   = "Terraform-GitOps"
  }
}

# 2. Recurso: Sub-rede Pública
resource "aws_subnet" "gitops_demo_subnet" {
  vpc_id                  = aws_vpc.gitops_demo_vpc.id
  cidr_block              = "10.60.1.0/24"
  availability_zone       = "us-east-1a" # Escolha uma AZ na sua região
  map_public_ip_on_launch = true

  tags = {
    Name = "GitOps-Demo-Public-Subnet"
  }
}

# 3. Recurso: Internet Gateway
resource "aws_internet_gateway" "gitops_demo_igw" {
  vpc_id = aws_vpc.gitops_demo_vpc.id

  tags = {
    Name = "GitOps-Demo-IGW"
  }
}

# 4. Recurso: Tabela de Rotas Pública
resource "aws_route_table" "gitops_demo_rt" {
  vpc_id = aws_vpc.gitops_demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gitops_demo_igw.id
  }

  tags = {
    Name = "GitOps-Demo-RT"
  }
}

# 5. Recurso: Associação da Tabela de Rotas à Sub-rede Pública
resource "aws_route_table_association" "gitops_demo_subnet_association" {
  subnet_id      = aws_subnet.gitops_demo_subnet.id
  route_table_id = aws_route_table.gitops_demo_rt.id
}

# Saídas (Outputs) para facilitar a verificação
output "gitops_vpc_id" {
  description = "The ID of the VPC managed by GitOps"
  value       = aws_vpc.gitops_demo_vpc.id
}

output "gitops_public_subnet_id" {
  description = "The ID of the public subnet managed by GitOps"
  value       = aws_subnet.gitops_demo_subnet.id
}