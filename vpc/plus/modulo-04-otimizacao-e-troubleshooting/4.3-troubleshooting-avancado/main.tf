# --- Exemplo de provisionamento via Terraform para Troubleshooting Avançado ---

# Este arquivo demonstra como configurar um cenário de rede na AWS para simular
# um problema de conectividade e, em seguida, usar ferramentas como o VPC Reachability Analyzer
# para diagnosticar a causa raiz.

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

# Variáveis para configuração do cenário
variable "vpc_cidr" {
  description = "CIDR block for the troubleshooting VPC."
  type        = string
  default     = "10.50.0.0/16"
}

variable "subnet_a_cidr" {
  description = "CIDR block for Subnet A."
  type        = string
  default     = "10.50.1.0/24"
}

variable "subnet_b_cidr" {
  description = "CIDR block for Subnet B."
  type        = string
  default     = "10.50.2.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the subnets."
  type        = string
  default     = "us-east-1a"
}

variable "key_pair_name" {
  description = "The name of the EC2 Key Pair to use for the instances."
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instances (e.g., Amazon Linux 2 AMI)."
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Exemplo para us-east-1 Amazon Linux 2
}

variable "my_local_ip" {
  description = "Your local public IP address for SSH access (e.g., 203.0.113.10/32)"
  type        = string
}

# --- 1. Criação da VPC e Sub-redes ---
resource "aws_vpc" "troubleshoot_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "Troubleshoot-VPC"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.troubleshoot_vpc.id
  cidr_block        = var.subnet_a_cidr
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true # Para facilitar o acesso SSH inicial

  tags = {
    Name = "Troubleshoot-Subnet-A"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.troubleshoot_vpc.id
  cidr_block        = var.subnet_b_cidr
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true # Para facilitar o acesso SSH inicial

  tags = {
    Name = "Troubleshoot-Subnet-B"
  }
}

# --- 2. Criação de Security Groups ---
resource "aws_security_group" "sg_a" {
  name        = "Troubleshoot-SG-A"
  description = "SG for Instance A"
  vpc_id      = aws_vpc.troubleshoot_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_local_ip]
    description = "Allow SSH from my IP"
  }

  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.subnet_b_cidr]
    description = "Allow outbound 8080 to Subnet B"
  }

  tags = {
    Name = "Troubleshoot-SG-A"
  }
}

resource "aws_security_group" "sg_b" {
  name        = "Troubleshoot-SG-B"
  description = "SG for Instance B"
  vpc_id      = aws_vpc.troubleshoot_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_local_ip]
    description = "Allow SSH from my IP"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.subnet_a_cidr]
    description = "Allow inbound 8080 from Subnet A"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "Troubleshoot-SG-B"
  }
}

# --- 3. Criação de Network ACLs ---
resource "aws_network_acl" "nacl_a" {
  vpc_id = aws_vpc.troubleshoot_vpc.id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    rule_no    = 100
    protocol   = "-1"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "Troubleshoot-NACL-A"
  }
}

resource "aws_network_acl_association" "nacl_a_association" {
  network_acl_id = aws_network_acl.nacl_a.id
  subnet_id      = aws_subnet.subnet_a.id
}

resource "aws_network_acl" "nacl_b" {
  vpc_id = aws_vpc.troubleshoot_vpc.id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    rule_no    = 100
    protocol   = "-1"
    rule_action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "Troubleshoot-NACL-B"
  }
}

resource "aws_network_acl_association" "nacl_b_association" {
  network_acl_id = aws_network_acl.nacl_b.id
  subnet_id      = aws_subnet.subnet_b.id
}

# --- 4. Lançamento das Instâncias EC2 ---
resource "aws_instance" "instance_a" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_a.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.sg_a.id]
  associate_public_ip_address = true

  tags = {
    Name = "Troubleshoot-Instance-A"
  }
}

resource "aws_instance" "instance_b" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_b.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.sg_b.id]
  associate_public_ip_address = true

  tags = {
    Name = "Troubleshoot-Instance-B"
  }
}

# --- 5. Injetar o Problema (Regra DENY na NACL-B) ---
# Esta regra bloqueará o tráfego TCP na porta 8080 vindo da Subnet A para a Subnet B.
resource "aws_network_acl_rule" "nacl_b_deny_rule" {
  network_acl_id = aws_network_acl.nacl_b.id
  rule_no        = 90 # Número baixo para ter precedência
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = var.subnet_a_cidr
  from_port      = 8080
  to_port        = 8080
  egress         = false # Inbound rule

  depends_on = [aws_network_acl.nacl_b] # Garante que a NACL exista antes de adicionar a regra
}

# Saídas (Outputs) para facilitar a verificação e o uso no Reachability Analyzer
output "instance_a_id" {
  description = "The ID of Instance A"
  value       = aws_instance.instance_a.id
}

output "instance_b_id" {
  description = "The ID of Instance B"
  value       = aws_instance.instance_b.id
}

output "instance_a_private_ip" {
  description = "The private IP of Instance A"
  value       = aws_instance.instance_a.private_ip
}

output "instance_b_private_ip" {
  description = "The private IP of Instance B"
  value       = aws_instance.instance_b.private_ip
}

output "nacl_b_id" {
  description = "The ID of NACL B (where the DENY rule is injected)"
  value       = aws_network_acl.nacl_b.id
}