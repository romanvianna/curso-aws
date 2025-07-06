# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um Placement Group do tipo Cluster,
# o lançamento de duas instâncias EC2 dentro dele e a configuração de um Security Group
# para permitir a comunicação entre elas, otimizando a performance de rede.

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

# Variáveis para configuração das instâncias
variable "vpc_id" {
  description = "The ID of the VPC where instances will be launched."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet where instances will be launched (must be in the same AZ)."
  type        = string
}

variable "key_pair_name" {
  description = "The name of the EC2 Key Pair to use for the instances."
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instances (e.g., Amazon Linux 2 AMI). Recommended to use an ENA-enabled AMI."
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Exemplo para us-east-1 Amazon Linux 2
}

variable "instance_type" {
  description = "The instance type for the EC2 instances (e.g., c5n.large for network performance)."
  type        = string
  default     = "c5n.large"
}

variable "my_local_ip" {
  description = "Your local public IP address for SSH access (e.g., 203.0.113.10/32)"
  type        = string
}

# 1. Recurso: Placement Group (Cluster)
# Agrupa as instâncias o mais próximo possível umas das outras para baixa latência e alto throughput.
resource "aws_placement_group" "hpc_cluster_pg" {
  name     = "HPC-Cluster-PG"
  strategy = "cluster"

  tags = {
    Name = "HPC-Cluster-PG"
  }
}

# 2. Recurso: Security Group para as Instâncias de Teste
# Permite todo o tráfego entre as instâncias no mesmo Security Group e SSH do seu IP.
resource "aws_security_group" "perf_test_sg" {
  name        = "Perf-Test-SG"
  description = "SG for network performance testing"
  vpc_id      = var.vpc_id

  # Permite todo o tráfego de entrada do próprio SG (para comunicação entre as instâncias no PG)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true # Referencia o próprio Security Group
    description = "Allow all traffic from self SG"
  }

  # Permite SSH do seu IP local
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
    Name = "Perf-Test-SG"
  }
}

# 3. Recurso: Instância 1 (Servidor iperf) no Placement Group
resource "aws_instance" "net_perf_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.perf_test_sg.id]
  associate_public_ip_address = true # Para acesso SSH inicial

  # Associa a instância ao Placement Group
  placement_group = aws_placement_group.hpc_cluster_pg.name

  tags = {
    Name = "Net-Perf-Server"
  }
}

# 4. Recurso: Instância 2 (Cliente iperf) no MESMO Placement Group
resource "aws_instance" "net_perf_client" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.perf_test_sg.id]
  associate_public_ip_address = true # Para acesso SSH inicial

  # Associa a instância ao MESMO Placement Group
  placement_group = aws_placement_group.hpc_cluster_pg.name

  tags = {
    Name = "Net-Perf-Client"
  }
}

# Saídas (Outputs) para facilitar a verificação e o acesso
output "placement_group_name" {
  description = "The name of the created Placement Group"
  value       = aws_placement_group.hpc_cluster_pg.name
}

output "perf_test_sg_id" {
  description = "The ID of the network performance test Security Group"
  value       = aws_security_group.perf_test_sg.id
}

output "net_perf_server_public_ip" {
  description = "Public IP address of the Net-Perf-Server instance"
  value       = aws_instance.net_perf_server.public_ip
}

output "net_perf_server_private_ip" {
  description = "Private IP address of the Net-Perf-Server instance"
  value       = aws_instance.net_perf_server.private_ip
}

output "net_perf_client_public_ip" {
  description = "Public IP address of the Net-Perf-Client instance"
  value       = aws_instance.net_perf_client.public_ip
}

output "net_perf_client_private_ip" {
  description = "Private IP address of the Net-Perf-Client instance"
  value       = aws_instance.net_perf_client.private_ip
}