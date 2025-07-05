# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra como o Terraform pode ser usado para gerenciar recursos da VPC.
# Embora o foco deste módulo seja a AWS CLI, este exemplo mostra a equivalência
# de algumas operações de "descrição" e "criação" de recursos da VPC usando Terraform.

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

# 1. Recurso: VPC (equivalente a aws ec2 create-vpc)
resource "aws_vpc" "cli_demo_vpc" {
  cidr_block = "10.20.0.0/16"

  tags = {
    Name = "Terraform-CLI-Demo-VPC"
  }
}

# 2. Recurso: Sub-rede (equivalente a aws ec2 create-subnet)
resource "aws_subnet" "cli_demo_subnet" {
  vpc_id            = aws_vpc.cli_demo_vpc.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "us-east-1a" # Escolha uma AZ na sua região

  tags = {
    Name = "Terraform-CLI-Demo-Subnet"
  }
}

# 3. Recurso: Internet Gateway (equivalente a aws ec2 create-internet-gateway)
resource "aws_internet_gateway" "cli_demo_igw" {
  vpc_id = aws_vpc.cli_demo_vpc.id

  tags = {
    Name = "Terraform-CLI-Demo-IGW"
  }
}

# 4. Data Source: Descrevendo a VPC (equivalente a aws ec2 describe-vpcs)
# Este bloco 'data' permite que o Terraform leia informações sobre um recurso
# que já existe na sua conta AWS, sem gerenciá-lo diretamente.
data "aws_vpc" "existing_vpc" {
  filter {
    name   = "tag:Name"
    values = ["Terraform-CLI-Demo-VPC"]
  }
  # Depende da criação da VPC acima para garantir que ela exista ao ser descrita
  depends_on = [aws_vpc.cli_demo_vpc]
}

# 5. Data Source: Descrevendo Sub-redes (equivalente a aws ec2 describe-subnets)
data "aws_subnet" "existing_subnet" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.cli_demo_vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["Terraform-CLI-Demo-Subnet"]
  }
  depends_on = [aws_subnet.cli_demo_subnet]
}

# Saídas (Outputs) para exibir informações dos recursos criados e descritos
output "created_vpc_id" {
  description = "The ID of the VPC created by Terraform"
  value       = aws_vpc.cli_demo_vpc.id
}

output "described_vpc_id" {
  description = "The ID of the VPC described by data source"
  value       = data.aws_vpc.existing_vpc.id
}

output "created_subnet_id" {
  description = "The ID of the subnet created by Terraform"
  value       = aws_subnet.cli_demo_subnet.id
}

output "described_subnet_id" {
  description = "The ID of the subnet described by data source"
  value       = data.aws_subnet.existing_subnet.id
}