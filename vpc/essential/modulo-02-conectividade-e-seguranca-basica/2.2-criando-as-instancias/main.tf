# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de instâncias EC2 em sub-redes públicas e privadas,
# associando-as aos Security Groups apropriados e a um Key Pair.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.custom_vpc').
# - Uma sub-rede pública existente (referenciada como 'aws_subnet.public_subnet').
# - Uma sub-rede privada existente (referenciada como 'aws_subnet.private_subnet').
# - Security Groups para o servidor web (WebServer-SG) e para o servidor DB (DBServer-SG).
# - Um Key Pair EC2 já importado na AWS.

# Variáveis para configuração das instâncias
variable "key_pair_name" {
  description = "The name of the EC2 Key Pair to use for the instances"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instances (e.g., Amazon Linux 2 AMI)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Exemplo para us-east-1 Amazon Linux 2
}

# Exemplo de como você pode referenciar a VPC, subnets e Security Groups
# se eles foram criados em outro lugar ou em um módulo anterior.
# resource "aws_vpc" "custom_vpc" {
#   # ... (configuração da VPC)
# }

# resource "aws_subnet" "public_subnet" {
#   # ... (configuração da sub-rede pública)
# }

# resource "aws_subnet" "private_subnet" {
#   # ... (configuração da sub-rede privada)
# }

# resource "aws_security_group" "web_server_sg" {
#   # ... (configuração do SG do servidor web)
# }

# resource "aws_security_group" "db_server_sg" {
#   # ... (configuração do SG do servidor DB)
# }

# 1. Instância EC2 para Servidor Web (WebServer-Lab)
# Lançada na sub-rede pública, com IP público e associada ao WebServer-SG.
resource "aws_instance" "web_server_lab" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = var.key_pair_name
  associate_public_ip_address = true # Habilita IP público
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  tags = {
    Name = "WebServer-Lab"
  }
}

# 2. Instância EC2 para Servidor de Banco de Dados (DBServer-Lab)
# Lançada na sub-rede privada, sem IP público e associada ao DBServer-SG.
resource "aws_instance" "db_server_lab" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id
  key_name      = var.key_pair_name
  associate_public_ip_address = false # Desabilita IP público
  vpc_security_group_ids = [aws_security_group.db_server_sg.id]

  tags = {
    Name = "DBServer-Lab"
  }
}

# Saídas (Outputs) para facilitar a verificação e o acesso
output "web_server_public_ip" {
  description = "Public IP address of the WebServer-Lab instance"
  value       = aws_instance.web_server_lab.public_ip
}

output "web_server_private_ip" {
  description = "Private IP address of the WebServer-Lab instance"
  value       = aws_instance.web_server_lab.private_ip
}

output "db_server_private_ip" {
  description = "Private IP address of the DBServer-Lab instance"
  value       = aws_instance.db_server_lab.private_ip
}