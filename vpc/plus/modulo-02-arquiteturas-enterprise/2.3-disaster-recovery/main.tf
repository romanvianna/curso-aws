# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a configuração de uma estratégia de Recuperação de Desastres (DR)
# utilizando o AWS Backup para proteger volumes EBS e replicá-los para uma região de DR.
# Ele também inclui a infraestrutura básica para simular uma estratégia Pilot Light.

# Bloco de configuração do Terraform para especificar os provedores AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a versão mais recente compatível
    }
  }
}

# Provedor para a região primária
provider "aws" {
  alias  = "primary"
  region = "us-east-1" # Região Primária (ex: N. Virginia)
}

# Provedor para a região de DR
provider "aws" {
  alias  = "dr"
  region = "us-east-2" # Região de DR (ex: Ohio)
}

# --- Parte 1: Configurar o AWS Backup (Backup e Restore) ---

# 1. IAM Role para o AWS Backup
# Esta role permite que o AWS Backup acesse e faça backup dos seus recursos.
resource "aws_iam_role" "backup_role" {
  provider = aws.primary
  name     = "AWSBackupRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "AWSBackupRole"
  }
}

resource "aws_iam_role_policy_attachment" "backup_policy_attachment" {
  provider   = aws.primary
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# 2. Cofre de Backup (Backup Vault) na região primária
resource "aws_backup_vault" "primary_backup_vault" {
  provider = aws.primary
  name     = "critical-data-vault-${random_id.vault_suffix.hex}"

  tags = {
    Name = "PrimaryBackupVault"
  }
}

# 3. Plano de Backup
resource "aws_backup_plan" "ebs_backup_plan" {
  provider = aws.primary
  name     = "EC2-Daily-Plan"

  rule {
    rule_name         = "Daily-EBS-Backup"
    target_vault_name = aws_backup_vault.primary_backup_vault.name
    schedule          = "cron(0 12 * * ? *)" # Diariamente às 12:00 UTC
    lifecycle {
      delete_after_days = 35
    }

    # Configuração de cópia para a região de DR
    copy_action {
      destination_backup_vault_arn = "arn:aws:backup:${aws.dr.region}:${data.aws_caller_identity.current.account_id}:backup-vault:${aws_backup_vault.dr_backup_vault.name}"
      lifecycle {
        delete_after_days = 35
      }
    }
  }

  tags = {
    Name = "EC2DailyBackupPlan"
  }
}

# 4. Seleção de Recursos para Backup (Exemplo: todos os volumes EBS com uma tag específica)
resource "aws_backup_selection" "ebs_selection" {
  provider     = aws.primary
  name         = "EC2-Volumes-Selection"
  plan_id      = aws_backup_plan.ebs_backup_plan.id
  iam_role_arn = aws_iam_role.backup_role.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }

  tags = {
    Name = "EC2VolumesSelection"
  }
}

# 5. Cofre de Backup na região de DR
resource "aws_backup_vault" "dr_backup_vault" {
  provider = aws.dr
  name     = "critical-data-vault-${random_id.vault_suffix.hex}"

  tags = {
    Name = "DRBackupVault"
  }
}

# --- Parte 2: Infraestrutura para Estratégia Pilot Light na Região de DR ---

# 1. VPC na Região de DR
resource "aws_vpc" "dr_vpc" {
  provider   = aws.dr
  cidr_block = "10.254.0.0/16"

  tags = {
    Name = "DR-PilotLight-VPC"
  }
}

# 2. Sub-rede Pública na Região de DR
resource "aws_subnet" "dr_public_subnet" {
  provider          = aws.dr
  vpc_id            = aws_vpc.dr_vpc.id
  cidr_block        = "10.254.1.0/24"
  availability_zone = "us-east-2a" # Escolha uma AZ na sua região de DR

  tags = {
    Name = "DR-Public-Subnet"
  }
}

# 3. Internet Gateway na Região de DR
resource "aws_internet_gateway" "dr_igw" {
  provider = aws.dr
  vpc_id   = aws_vpc.dr_vpc.id

  tags = {
    Name = "DR-IGW"
  }
}

# 4. Tabela de Rotas Pública na Região de DR
resource "aws_route_table" "dr_public_rt" {
  provider = aws.dr
  vpc_id   = aws_vpc.dr_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr_igw.id
  }

  tags = {
    Name = "DR-Public-RT"
  }
}

# 5. Associação da Tabela de Rotas à Sub-rede Pública na Região de DR
resource "aws_route_table_association" "dr_public_subnet_association" {
  provider       = aws.dr
  subnet_id      = aws_subnet.dr_public_subnet.id
  route_table_id = aws_route_table.dr_public_rt.id
}

# Recurso auxiliar para gerar um sufixo único
resource "random_id" "vault_suffix" {
  byte_length = 8
}

# Data source para obter o Account ID (usado no ARN do backup vault de destino)
data "aws_caller_identity" "current" {
  provider = aws.primary
}

# Saídas (Outputs) para facilitar a verificação
output "primary_backup_vault_name" {
  description = "Name of the primary backup vault"
  value       = aws_backup_vault.primary_backup_vault.name
}

output "dr_backup_vault_name" {
  description = "Name of the DR backup vault"
  value       = aws_backup_vault.dr_backup_vault.name
}

output "dr_vpc_id" {
  description = "ID of the DR VPC"
  value       = aws_vpc.dr_vpc.id
}