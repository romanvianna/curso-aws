# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um VPC Endpoint de Gateway para S3
# e um VPC Endpoint de Interface para EC2 API, permitindo acesso privado
# a esses serviços a partir de sub-redes privadas.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.custom_vpc').
# - Uma tabela de rotas privada existente (referenciada como 'aws_route_table.private_route_table').
# - Sub-redes privadas existentes em pelo menos duas AZs (referenciadas como 'aws_subnet.private_subnet_az1' e 'aws_subnet.private_subnet_az2').
# - Um Security Group para o Interface Endpoint (referenciado como 'aws_security_group.ec2_endpoint_sg').

# Exemplo de definições de VPC, subnets e security group (se não existirem):
# resource "aws_vpc" "custom_vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = { Name = "LabVPC" }
# }

# resource "aws_subnet" "private_subnet_az1" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.3.0/24"
#   availability_zone = "us-east-1a"
#   tags = { Name = "LabPrivateSubnetAZ1" }
# }

# resource "aws_subnet" "private_subnet_az2" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.4.0/24"
#   availability_zone = "us-east-1b"
#   tags = { Name = "LabPrivateSubnetAZ2" }
# }

# resource "aws_route_table" "private_route_table" {
#   vpc_id = aws_vpc.custom_vpc.id
#   tags = { Name = "LabPrivateRouteTable" }
# }

# resource "aws_security_group" "ec2_endpoint_sg" {
#   name        = "LabEC2EndpointSG"
#   description = "Allow HTTPS to EC2 Interface Endpoint"
#   vpc_id      = aws_vpc.custom_vpc.id
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     # Permite acesso de todas as sub-redes privadas da VPC
#     cidr_blocks = [aws_vpc.custom_vpc.cidr_block]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = { Name = "LabEC2EndpointSG" }
# }

# 1. Criação do VPC Endpoint de Gateway para S3
# Este endpoint permite que instâncias em sub-redes privadas acessem o S3
# sem precisar passar pelo NAT Gateway ou Internet Gateway. O tráfego permanece
# na rede da AWS.
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id       = aws_vpc.custom_vpc.id
  service_name = "com.amazonaws.us-east-1.s3" # Nome do serviço S3 na região
  vpc_endpoint_type = "Gateway" # Tipo Gateway para S3 e DynamoDB

  # Associa o endpoint à tabela de rotas da sub-rede privada.
  # O Terraform adicionará automaticamente a rota para o prefix list do S3.
  route_table_ids = [aws_route_table.private_route_table.id]

  # Opcional: Política de endpoint para granular o acesso ao S3 via este endpoint.
  # policy = jsonencode({
  #   Version = "2012-10-17"
  #   Statement = [
  #     {
  #       Effect    = "Allow"
  #       Principal = "*"
  #       Action    = "s3:GetObject"
  #       Resource  = "arn:aws:s3:::your-specific-bucket/*"
  #     },
  #   ]
  # })

  tags = { Name = "LabS3GatewayEndpoint" }
}

# 2. Criação do VPC Endpoint de Interface para EC2 API
# Este endpoint permite que instâncias em sub-redes privadas façam chamadas
# para a API do EC2 (ex: describe-instances) sem sair da VPC.
resource "aws_vpc_endpoint" "ec2_interface_endpoint" {
  vpc_id            = aws_vpc.custom_vpc.id
  service_name      = "com.amazonaws.us-east-1.ec2" # Nome do serviço EC2 API na região
  vpc_endpoint_type = "Interface" # Tipo Interface para a maioria dos serviços AWS

  # O endpoint será provisionado nas sub-redes privadas para alta disponibilidade.
  subnet_ids        = [aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id]

  # Associa um Security Group para controlar o tráfego de entrada para o endpoint.
  security_group_ids = [aws_security_group.ec2_endpoint_sg.id]

  # Habilita o DNS privado para que as chamadas para o nome público do serviço
  # sejam resolvidas para o IP privado do endpoint dentro da VPC.
  private_dns_enabled = true

  tags = { Name = "LabEC2InterfaceEndpoint" }
}

# Saídas (Outputs) para facilitar a referência e verificação
output "s3_gateway_endpoint_id" {
  description = "The ID of the S3 Gateway VPC Endpoint"
  value       = aws_vpc_endpoint.s3_gateway_endpoint.id
}

output "ec2_interface_endpoint_id" {
  description = "The ID of the EC2 Interface VPC Endpoint"
  value       = aws_vpc_endpoint.ec2_interface_endpoint.id
}

output "ec2_interface_endpoint_dns_entries" {
  description = "DNS entries for the EC2 Interface VPC Endpoint"
  value       = aws_vpc_endpoint.ec2_interface_endpoint.dns_entry
}