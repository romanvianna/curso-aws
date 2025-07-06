# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação dos componentes virtuais da AWS necessários
# para uma conexão AWS Direct Connect, como o Virtual Private Gateway (VGW)
# e o Direct Connect Gateway (DXGW), e sua associação.
#
# Importante: A criação da conexão física do Direct Connect e da Virtual Interface (VIF)
# é um processo que envolve a AWS, o cliente e, muitas vezes, um parceiro de rede.
# Essas etapas não são totalmente automatizáveis via Terraform, mas os componentes
# do lado da AWS podem ser gerenciados aqui.

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
#   Ex: resource "aws_vpc" "lab_vpc" { cidr_block = "10.0.0.0/16" tags = { Name = "Lab-VPC-DX" } }

# Variáveis para configuração
variable "vpc_id" {
  description = "The ID of the VPC to attach the VGW to."
  type        = string
}

variable "on_premises_asn" {
  description = "The ASN of your on-premises network (e.g., 65000)."
  type        = string
}

variable "dx_gateway_asn" {
  description = "The Amazon-side ASN for the Direct Connect Gateway (private ASN, e.g., 65001)."
  type        = string
}

# 1. Recurso: Virtual Private Gateway (VGW)
# O VGW é o gateway do lado da VPC para conexões VPN e Direct Connect.
resource "aws_vpn_gateway" "lab_vgw" {
  vpc_id = var.vpc_id
  amazon_side_asn = var.on_premises_asn # O ASN do seu lado, para BGP

  tags = {
    Name = "Lab-VGW"
  }
}

# 2. Recurso: Direct Connect Gateway (DXGW)
# O DXGW é um recurso global que permite conectar sua conexão DX a múltiplas VPCs
# em diferentes regiões ou contas.
resource "aws_dx_gateway" "lab_dx_gateway" {
  name            = "Lab-DXGW"
  amazon_side_asn = var.dx_gateway_asn # O ASN do lado da Amazon para o DXGW

  tags = {
    Name = "Lab-DXGW"
  }
}

# 3. Recurso: Associação do VGW ao DXGW
# Esta associação permite que o tráfego do DXGW seja roteado para a VPC através do VGW.
resource "aws_dx_gateway_association" "lab_dx_gateway_association" {
  dx_gateway_id = aws_dx_gateway.lab_dx_gateway.id
  gateway_id    = aws_vpn_gateway.lab_vgw.id

  # Garante que o VGW e o DXGW existam antes de tentar associá-los
  depends_on = [aws_vpn_gateway.lab_vgw, aws_dx_gateway.lab_dx_gateway]
}

# Saídas (Outputs) para facilitar a referência e verificação
output "vgw_id" {
  description = "The ID of the Virtual Private Gateway"
  value       = aws_vpn_gateway.lab_vgw.id
}

output "dx_gateway_id" {
  description = "The ID of the Direct Connect Gateway"
  value       = aws_dx_gateway.lab_dx_gateway.id
}

output "dx_gateway_association_id" {
  description = "The ID of the Direct Connect Gateway Association"
  value       = aws_dx_gateway_association.lab_dx_gateway_association.id
}