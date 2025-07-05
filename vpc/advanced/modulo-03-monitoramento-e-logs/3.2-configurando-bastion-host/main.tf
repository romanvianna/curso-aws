# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um Bastion Host em uma sub-rede pública
# e a configuração de Security Groups para permitir acesso SSH seguro a instâncias
# em sub-redes privadas, utilizando o princípio do menor privilégio.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.custom_vpc').
# - Uma sub-rede pública existente (referenciada como 'aws_subnet.public_subnet').
# - Uma sub-rede privada existente (referenciada como 'aws_subnet.private_subnet').
# - Um Security Group para as instâncias privadas (referenciada como 'aws_security_group.private_instance_sg').
# - Um par de chaves EC2 já importado na AWS.

# Variáveis para configuração do Bastion Host
variable "key_pair_name" {
  description = "The name of the EC2 Key Pair to use for the Bastion Host"
  type        = string
}

variable "my_local_ip" {
  description = "Your local public IP address for SSH access to the Bastion Host (e.g., 203.0.113.10/32)"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the Bastion Host (e.g., Amazon Linux 2 AMI)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Exemplo para us-east-1 Amazon Linux 2
}

# 1. Security Group para o Bastion Host
# Permite SSH apenas do seu IP local e permite saída SSH para a sub-rede privada.
resource "aws_security_group" "bastion_sg" {
  name        = "BastionHostSG"
  description = "Security Group for Bastion Host"
  vpc_id      = aws_vpc.custom_vpc.id

  # Regra de entrada: Permite SSH apenas do seu IP local
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_local_ip]
    description = "Allow SSH from local IP"
  }

  # Regra de saída: Permite SSH para a sub-rede privada
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet.cidr_block]
    description = "Allow SSH to private subnet"
  }

  tags = { Name = "BastionHostSG" }
}

# 2. Instância EC2 do Bastion Host
# Lançada na sub-rede pública com o SG configurado.
resource "aws_instance" "bastion_host" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = var.key_pair_name
  associate_public_ip_address = true # Necessário para acesso da internet
  security_groups = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "BastionHost"
  }
}

# 3. Modifica o Security Group da Instância Privada
# Adiciona uma regra para permitir SSH da Security Group do Bastion Host.
# Assumimos que 'aws_security_group.private_instance_sg' já existe e está associado às instâncias privadas.
resource "aws_security_group_rule" "allow_ssh_from_bastion" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id = aws_security_group.private_instance_sg.id # SG da sua instância privada
  description       = "Allow SSH from Bastion Host"
}

# Saídas (Outputs) para facilitar a referência e verificação
output "bastion_public_ip" {
  description = "The public IP address of the Bastion Host"
  value       = aws_instance.bastion_host.public_ip
}

output "bastion_private_ip" {
  description = "The private IP address of the Bastion Host"
  value       = aws_instance.bastion_host.private_ip
}

output "bastion_sg_id" {
  description = "The ID of the Bastion Host Security Group"
  value       = aws_security_group.bastion_sg.id
}