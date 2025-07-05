# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação e configuração de VPC Flow Logs e AWS CloudTrail
# para uma VPC, enviando os logs para um bucket S3 e para o CloudWatch Logs.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.custom_vpc').

# 1. Criação do Bucket S3 para VPC Flow Logs
# Este bucket armazenará os logs de fluxo da VPC.
resource "aws_s3_bucket" "flow_log_bucket" {
  bucket = "my-vpc-flow-logs-bucket-${random_id.bucket_suffix.hex}" # Nome único

  tags = {
    Name = "VPCFlowLogsBucket"
  }
}

# Recurso auxiliar para gerar um sufixo único para o nome do bucket
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# 2. IAM Role para VPC Flow Logs
# Esta role concede permissão ao serviço VPC Flow Logs para publicar logs no S3 e CloudWatch Logs.
resource "aws_iam_role" "flow_log_role" {
  name = "VPCFlowLogRole-${random_id.role_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "VPCFlowLogRole"
  }
}

# Recurso auxiliar para gerar um sufixo único para o nome da role
resource "random_id" "role_suffix" {
  byte_length = 4
}

# 3. IAM Policy para VPC Flow Logs
# Esta política define as permissões que a role terá para escrever logs.
resource "aws_iam_role_policy" "flow_log_policy" {
  name = "VPCFlowLogPolicy-${random_id.policy_suffix.hex}"
  role = aws_iam_role.flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*" # Permite criar grupos e streams de log
      },
      {
        Action = [
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.flow_log_bucket.arn}/*" # Permite escrever objetos no bucket S3
      },
    ]
  })

  tags = {
    Name = "VPCFlowLogPolicy"
  }
}

# Recurso auxiliar para gerar um sufixo único para o nome da policy
resource "random_id" "policy_suffix" {
  byte_length = 4
}

# 4. Configuração do VPC Flow Log
# Habilita o Flow Log para a VPC, enviando para o S3 e CloudWatch Logs.
resource "aws_flow_log" "lab_vpc_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_s3_bucket.flow_log_bucket.arn
  traffic_type    = "ALL" # Captura todo o tráfego (ACCEPT e REJECT)
  vpc_id          = aws_vpc.custom_vpc.id

  # Formato de log customizado para incluir mais detalhes para análise
  log_format = "${join(" ", [
    "version",
    "account-id",
    "interface-id",
    "srcaddr",
    "dstaddr",
    "srcport",
    "dstport",
    "protocol",
    "packets",
    "bytes",
    "start",
    "end",
    "action",
    "log-status",
    "vpc-id",
    "subnet-id",
    "instance-id",
    "tcp-flags",
    "type",
    "pkt-srcaddr",
    "pkt-dstaddr"
  ])}"

  tags = {
    Name = "LabVPCFlowLog"
  }
}

# 5. Criação do Bucket S3 para CloudTrail
# Este bucket armazenará os logs de eventos da API da AWS.
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "my-cloudtrail-logs-bucket-${random_id.cloudtrail_bucket_suffix.hex}" # Nome único

  tags = {
    Name = "CloudTrailLogsBucket"
  }
}

resource "random_id" "cloudtrail_bucket_suffix" {
  byte_length = 8
}

# 6. IAM Role para CloudTrail (para publicar logs no CloudWatch Logs)
resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  name = "CloudTrailCloudWatchRole-${random_id.cloudtrail_role_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "CloudTrailCloudWatchRole"
  }
}

resource "random_id" "cloudtrail_role_suffix" {
  byte_length = 4
}

# 7. IAM Policy para CloudTrail (para publicar logs no CloudWatch Logs)
resource "aws_iam_role_policy" "cloudtrail_cloudwatch_policy" {
  name = "CloudTrailCloudWatchPolicy-${random_id.cloudtrail_policy_suffix.hex}"
  role = aws_iam_role.cloudtrail_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:log-group:/aws/cloudtrail/*:*" # Permite escrever em log groups do CloudTrail
      },
    ]
  })

  tags = {
    Name = "CloudTrailCloudWatchPolicy"
  }
}

resource "random_id" "cloudtrail_policy_suffix" {
  byte_length = 4
}

# 8. Configuração do AWS CloudTrail
# Habilita o CloudTrail para registrar eventos de gerenciamento e enviar para S3 e CloudWatch Logs.
resource "aws_cloudtrail" "lab_cloudtrail" {
  name                          = "lab-organization-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true # Inclui eventos de serviços globais como IAM
  is_multi_region_trail         = true # Registra eventos em todas as regiões
  enable_logging                = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch_role.arn

  tags = {
    Name = "LabCloudTrail"
  }
}

# 9. CloudWatch Log Group para CloudTrail
# O grupo de logs onde o CloudTrail publicará os eventos.
resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/cloudtrail/lab-organization-trail"
  retention_in_days = 90 # Exemplo de retenção de 90 dias

  tags = {
    Name = "CloudTrailLogGroup"
  }
}

# Saídas (Outputs) para facilitar a referência e verificação
output "flow_log_bucket_name" {
  description = "Name of the S3 bucket for VPC Flow Logs"
  value       = aws_s3_bucket.flow_log_bucket.id
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_bucket.id
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.lab_cloudtrail.arn
}