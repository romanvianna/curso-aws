# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra como habilitar o Amazon GuardDuty e o AWS Security Hub
# usando Terraform. Ele também inclui a criação de uma instância EC2 que pode
# ser usada para simular um finding de segurança.

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

# Variáveis para a instância de teste
variable "key_pair_name" {
  description = "The name of the EC2 Key Pair to use for the test instance"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the EC2 test instance (e.g., Amazon Linux 2 AMI)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Exemplo para us-east-1 Amazon Linux 2
}

variable "subnet_id" {
  description = "The ID of a public subnet where the test instance will be launched"
  type        = string
}

variable "security_group_ids" {
  description = "A list of Security Group IDs for the test instance (must allow SSH from your IP)"
  type        = list(string)
}

# --- 1. Habilitar o Amazon GuardDuty ---
resource "aws_guardduty_detector" "main_detector" {
  enable = true

  tags = {
    Name = "GuardDuty-Main-Detector"
  }
}

# --- 2. Habilitar o AWS Security Hub ---
resource "aws_securityhub_account" "main_securityhub" {
  # Habilita o Security Hub na conta atual
  # Não há atributos específicos para configurar aqui, apenas a existência do recurso o habilita.
}

# Opcional: Habilitar padrões de segurança no Security Hub
resource "aws_securityhub_standards_subscription" "cis_benchmark" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0" # CIS AWS Foundations Benchmark
  depends_on    = [aws_securityhub_account.main_securityhub]
}

resource "aws_securityhub_standards_subscription" "aws_foundational_security_best_practices" {
  standards_arn = "arn:aws:securityhub:::ruleset/aws-foundational-security-best-practices/v/1.0.0" # AWS Foundational Security Best Practices
  depends_on    = [aws_securityhub_account.main_securityhub]
}

# --- 3. Instância EC2 para Gerar Findings (Simulação) ---
# Esta instância pode ser usada para executar comandos que o GuardDuty detectaria.
resource "aws_instance" "guardduty_test_instance" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id
  key_name      = var.key_pair_name
  vpc_security_group_ids = var.security_group_ids
  associate_public_ip_address = true # Para acesso SSH e simulação de tráfego externo

  tags = {
    Name = "GuardDuty-Test-Instance"
  }

  # Garante que o GuardDuty esteja habilitado antes de lançar a instância para detecção
  depends_on = [aws_guardduty_detector.main_detector]
}

# Saídas (Outputs) para facilitar a verificação
output "guardduty_detector_id" {
  description = "The ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main_detector.id
}

output "securityhub_account_id" {
  description = "The AWS Account ID where Security Hub is enabled"
  value       = aws_securityhub_account.main_securityhub.id
}

output "test_instance_public_ip" {
  description = "Public IP of the GuardDuty test instance"
  value       = aws_instance.guardduty_test_instance.public_ip
}

output "test_instance_id" {
  description = "ID of the GuardDuty test instance"
  value       = aws_instance.guardduty_test_instance.id
}