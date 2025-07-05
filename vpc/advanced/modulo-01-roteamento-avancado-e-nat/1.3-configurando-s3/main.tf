# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um bucket S3 e a aplicação de uma política
# de bucket para restringir o acesso a partir de um IP de origem específico,
# simulando o acesso de instâncias em uma sub-rede privada via NAT Gateway.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Um Elastic IP (EIP) associado a um NAT Gateway (para usar seu IP público na política).
#   Exemplo de referência: `aws_eip.nat_gateway_eip.public_ip`

# 1. Criação do Bucket S3
# O bucket será privado por padrão (Block Public Access habilitado).
resource "aws_s3_bucket" "lab_s3_bucket" {
  bucket = "lab-vpc-s3-bucket-${random_id.bucket_suffix.hex}" # Nome único para o bucket

  tags = {
    Name = "LabS3Bucket"
    Environment = "Development"
  }
}

# Recurso auxiliar para gerar um sufixo único para o nome do bucket
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# 2. Aplicação da Política de Bucket
# Esta política nega todo o acesso ao bucket, exceto se a requisição
# vier de um IP específico (o IP público do nosso NAT Gateway).
resource "aws_s3_bucket_policy" "lab_s3_bucket_policy" {
  bucket = aws_s3_bucket.lab_s3_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForNATIP"
    Statement = [
      {
        Sid       = "DenyAccessUnlessFromNAT"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.lab_s3_bucket.arn,
          "${aws_s3_bucket.lab_s3_bucket.arn}/*",
        ]
        Condition = {
          NotIpAddress = {
            "aws:SourceIp" = ["${aws_eip.nat_gateway_eip.public_ip}/32"] # Substitua pela referência do seu EIP do NAT GW
          }
        }
      },
    ]
  })
}

# Saídas (Outputs) para facilitar a referência e verificação
output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.lab_s3_bucket.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.lab_s3_bucket.arn
}