# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação e configuração de Security Groups e Network ACLs
# para uma arquitetura de 3 camadas (Web, App, DB) em uma VPC.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.custom_vpc').
# - Sub-redes para cada camada (Web, App, DB) em diferentes AZs para alta disponibilidade.
#   Ex: aws_subnet.web_subnet, aws_subnet.app_subnet, aws_subnet.db_subnet

# Exemplo de definições de VPC e subnets (se não existirem):
# resource "aws_vpc" "custom_vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = { Name = "LabVPC" }
# }

# resource "aws_subnet" "web_subnet" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.1.0/24"
#   availability_zone = "us-east-1a"
#   map_public_ip_on_launch = true
#   tags = { Name = "LabWebSubnet" }
# }

# resource "aws_subnet" "app_subnet" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.2.0/24"
#   availability_zone = "us-east-1a"
#   tags = { Name = "LabAppSubnet" }
# }

# resource "aws_subnet" "db_subnet" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.3.0/24"
#   availability_zone = "us-east-1a"
#   tags = { Name = "LabDBSubnet" }
# }

# Variável para o seu IP local (para acesso SSH)
variable "my_local_ip" {
  description = "Your local public IP address for SSH access (e.g., 203.0.113.10/32)"
  type        = string
}

# --- Security Groups (Stateful - Nível da Instância) ---

# Security Group para a Camada Web
resource "aws_security_group" "web_sg" {
  name        = "WebSG"
  description = "Allow HTTP/HTTPS/SSH to Web Layer"
  vpc_id      = aws_vpc.custom_vpc.id

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

  tags = { Name = "WebSG" }
}

# Security Group para a Camada de Aplicação
resource "aws_security_group" "app_sg" {
  name        = "AppSG"
  description = "Allow traffic from WebSG to App Layer"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 8080 # Porta da aplicação
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Permite acesso apenas do WebSG
    description = "Allow App traffic from WebSG"
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

  tags = { Name = "AppSG" }
}

# Security Group para a Camada de Banco de Dados
resource "aws_security_group" "db_sg" {
  name        = "DBSG"
  description = "Allow traffic from AppSG to DB Layer"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 3306 # Porta do MySQL/PostgreSQL
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Permite acesso apenas do AppSG
    description = "Allow DB traffic from AppSG"
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

  tags = { Name = "DBSG" }
}

# --- Network ACLs (Stateless - Nível da Sub-rede) ---

# Network ACL para a Sub-rede do Banco de Dados (DB-NACL)
# Esta NACL é mais restritiva e serve como uma camada extra de defesa.
resource "aws_network_acl" "db_nacl" {
  vpc_id = aws_vpc.custom_vpc.id

  # Regras de Entrada (Inbound)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 3306
    to_port    = 3306
    cidr_block = aws_subnet.app_subnet.cidr_block # Permite tráfego da sub-rede da aplicação
    description = "Allow DB traffic from App Subnet"
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 1024 # Portas efêmeras para respostas
    to_port    = 65535
    cidr_block = aws_subnet.app_subnet.cidr_block
    description = "Allow ephemeral ports from App Subnet for responses"
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 22
    to_port    = 22
    cidr_block = var.my_local_ip
    description = "Allow SSH from my local IP"
  }

  # Regras de Saída (Outbound)
  egress {
    rule_no    = 100
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 3306
    to_port    = 3306
    cidr_block = aws_subnet.app_subnet.cidr_block
    description = "Allow DB traffic to App Subnet"
  }

  egress {
    rule_no    = 110
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 1024 # Portas efêmeras para respostas
    to_port    = 65535
    cidr_block = aws_subnet.app_subnet.cidr_block
    description = "Allow ephemeral ports to App Subnet for responses"
  }

  egress {
    rule_no    = 120
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 22
    to_port    = 22
    cidr_block = var.my_local_ip
    description = "Allow SSH to my local IP"
  }

  tags = { Name = "DB-NACL" }
}

# Associação da DB-NACL à Sub-rede do Banco de Dados
resource "aws_network_acl_association" "db_subnet_nacl_association" {
  network_acl_id = aws_network_acl.db_nacl.id
  subnet_id      = aws_subnet.db_subnet.id
}

# Exemplo de Blacklisting em NACL Pública (assumindo que web_subnet tem uma NACL padrão)
# Você precisaria obter o ID da NACL padrão da sub-rede web e adicionar a regra.
# Para este exemplo, vamos criar uma NACL customizada para a sub-rede web para demonstrar.
resource "aws_network_acl" "web_nacl" {
  vpc_id = aws_vpc.custom_vpc.id

  # Regra de DENY para um IP malicioso conhecido
  ingress {
    rule_no    = 90 # Número baixo para ser avaliado primeiro
    protocol   = "all"
    rule_action = "deny"
    cidr_block = "203.0.113.5/32" # IP do atacante
    description = "Deny known malicious IP"
  }

  # Regras ALLOW para tráfego web (exemplo, ajuste conforme necessário)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
    description = "Allow HTTP"
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
    description = "Allow HTTPS"
  }
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    rule_action = "allow"
    from_port  = 22
    to_port    = 22
    cidr_block = var.my_local_ip
    description = "Allow SSH from my local IP"
  }

  # Regras de Saída (Outbound) - Permitir tudo por padrão para este exemplo
  egress {
    rule_no    = 100
    protocol   = "all"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
    description = "Allow all outbound traffic"
  }

  tags = { Name = "Web-NACL" }
}

# Associação da Web-NACL à Sub-rede Web
resource "aws_network_acl_association" "web_subnet_nacl_association" {
  network_acl_id = aws_network_acl.web_nacl.id
  subnet_id      = aws_subnet.web_subnet.id
}

# Saídas (Outputs) para facilitar a referência e verificação
output "web_sg_id" {
  description = "The ID of the Web Security Group"
  value       = aws_security_group.web_sg.id
}

output "app_sg_id" {
  description = "The ID of the App Security Group"
  value       = aws_security_group.app_sg.id
}

output "db_sg_id" {
  description = "The ID of the DB Security Group"
  value       = aws_security_group.db_sg.id
}

output "db_nacl_id" {
  description = "The ID of the DB Network ACL"
  value       = aws_network_acl.db_nacl.id
}

output "web_nacl_id" {
  description = "The ID of the Web Network ACL"
  value       = aws_network_acl.web_nacl.id
}