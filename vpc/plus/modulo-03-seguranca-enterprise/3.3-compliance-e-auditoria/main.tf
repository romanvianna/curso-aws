# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra como configurar o AWS Config para conformidade e auditoria.
# Ele habilita o AWS Config, cria um bucket S3 para logs, uma IAM Role e adiciona
# uma regra gerenciada para detectar Security Groups não conformes (SSH aberto para 0.0.0.0/0).
# Também configura a remediação automática para essa regra.

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

# --- 1. Criação do Bucket S3 para o AWS Config ---
# Este bucket armazenará o histórico de configuração e os logs de entrega do Config.
resource "aws_s3_bucket" "config_bucket" {
  bucket = "aws-config-bucket-${data.aws_caller_identity.current.account_id}-${var.aws_region}" # Nome único

  tags = {
    Name = "AWS-Config-Bucket"
  }
}

# Bloquear acesso público ao bucket do Config (melhor prática)
resource "aws_s3_bucket_public_access_block" "config_bucket_public_access_block" {
  bucket = aws_s3_bucket.config_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Criação da IAM Role para o AWS Config
# Esta role concede permissão ao serviço AWS Config para acessar seus recursos e entregar logs.
resource "aws_iam_role" "config_role" {
  name = "aws-service-role-config-${random_id.role_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "AWS-Config-Role"
  }
}

# Anexar a política gerenciada ao role
resource "aws_iam_role_policy_attachment" "config_policy_attachment" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# 3. Configuração do Gravador de Configuração (Configuration Recorder)
# Habilita o registro de alterações de configuração para todos os recursos suportados.
resource "aws_config_configuration_recorder" "recorder" {
  name     = "default"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
}

# 4. Configuração do Canal de Entrega (Delivery Channel)
# Define onde o AWS Config entregará os logs de configuração.
resource "aws_config_delivery_channel" "channel" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.config_bucket.id

  depends_on = [aws_config_configuration_recorder.recorder] # Garante que o recorder esteja pronto
}

# 5. Iniciar o Gravador de Configuração
resource "aws_config_configuration_recorder_status" "recorder_status" {
  name       = aws_config_configuration_recorder.recorder.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.channel] # Garante que o delivery channel esteja pronto
}

# 6. Adicionar a Regra de Detecção (restricted-ssh)
# Esta regra gerenciada verifica se nenhum Security Group permite SSH de 0.0.0.0/0.
resource "aws_config_config_rule" "restricted_ssh_rule" {
  name = "restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "RESTRICTED_SSH"
  }

  scope {
    compliance_resource_types = ["AWS::EC2::SecurityGroup"]
  }

  tags = {
    Name = "Restricted-SSH-Rule"
  }
}

# 7. Configurar a Remediação Automática para a Regra
# Esta ação de remediação será acionada quando a regra 'restricted-ssh' for violada.
resource "aws_config_remediation_configuration" "restricted_ssh_remediation" {
  config_rule_name = aws_config_config_rule.restricted_ssh_rule.name
  resource_type    = "AWS::EC2::SecurityGroup"
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-DisablePublicAccessForSecurityGroup" # Documento SSM para remediação
  automatic        = true

  parameter {
    name  = "IpProtocol"
    value = "tcp"
  }
  parameter {
    name  = "FromPort"
    value = "22"
  }
  parameter {
    name  = "ToPort""
    value = "22"
  }
  parameter {
    name  = "CidrIp"
    value = "0.0.0.0/0"
  }

  # IAM Role para a remediação (criada automaticamente pelo Config se não existir)
  # Certifique-se de que esta role tem permissões para executar o documento SSM e modificar SGs.
  # aws_config_remediation_configuration.restricted_ssh_remediation.target_id

  depends_on = [aws_config_config_rule.restricted_ssh_rule] # Garante que a regra exista antes de configurar a remediação
}

# Recurso auxiliar para gerar um sufixo único para o nome da role
resource "random_id" "role_suffix" {
  byte_length = 4
}

# Data source para obter o Account ID e a região atual
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Saídas (Outputs) para facilitar a verificação
output "config_bucket_name" {
  description = "Name of the S3 bucket used by AWS Config"
  value       = aws_s3_bucket.config_bucket.id
}

output "config_recorder_status" {
  description = "Status of the AWS Config recorder"
  value       = aws_config_configuration_recorder_status.recorder_status.is_enabled
}

output "restricted_ssh_rule_arn" {
  description = "ARN of the restricted-ssh Config Rule"
  value       = aws_config_config_rule.restricted_ssh_rule.arn
}