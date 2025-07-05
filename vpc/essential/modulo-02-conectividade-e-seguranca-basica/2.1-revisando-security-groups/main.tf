# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de Security Groups para uma arquitetura
# de duas camadas (Web e Banco de Dados), utilizando referências de Security Group
# para permitir comunicação segura e granular entre elas.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.custom_vpc').

# Variáveis para configuração
variable "vpc_id" {
  description = "The ID of the VPC where the Security Groups will be created."
  type        = string
}

variable "my_local_ip" {
  description = "Your local public IP address for SSH access (e.g., 203.0.113.10/32)"
  type        = string
}

# 1. Security Group para Servidor Web (WebServer-SG)
# Permite tráfego HTTP, HTTPS de qualquer lugar e SSH do seu IP local.
resource "aws_security_group" "web_server_sg" {
  name        = "WebServer-SG"
  description = "Security Group for Web Servers"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_local_ip]
    description = "Allow SSH from my local IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "WebServer-SG"
  }
}

# 2. Security Group para Servidor de Banco de Dados (DBServer-SG)
# Permite tráfego MySQL/Aurora apenas do WebServer-SG e SSH do seu IP local.
resource "aws_security_group" "db_server_sg" {
  name        = "DBServer-SG"
  description = "Security Group for Database Servers"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web_server_sg.id] # Permite acesso apenas do WebServer-SG
    description = "Allow MySQL/Aurora from WebServer-SG"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_local_ip]
    description = "Allow SSH from my local IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "DBServer-SG"
  }
}

# Saídas (Outputs) para facilitar a referência e verificação
output "web_server_sg_id" {
  description = "The ID of the WebServer Security Group"
  value       = aws_security_group.web_server_sg.id
}

output "db_server_sg_id" {
  description = "The ID of the DBServer Security Group"
  value       = aws_security_group.db_server_sg.id
}