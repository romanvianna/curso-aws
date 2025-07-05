# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra o Controle de Acesso Baseado em Atributos (ABAC) no IAM
# usando Terraform. Criaremos uma política que permite iniciar/parar instâncias EC2
# apenas se a tag 'Project' da instância corresponder à tag 'Project' da role
# que está realizando a ação.

# Pré-requisitos:
# - Instâncias EC2 existentes com a tag 'Project' (ex: Project: Helio, Project: Artemis).

# 1. Política IAM com ABAC
# Esta política permite 'DescribeInstances' para listar todas as instâncias,
# mas restringe 'StopInstances', 'StartInstances', 'RebootInstances'
# apenas para instâncias onde a tag 'Project' do recurso é igual à tag 'Project' do principal.
resource "aws_iam_policy" "developer_project_access_policy" {
  name        = "DeveloperProjectAccessPolicy"
  description = "Allows EC2 start/stop based on Project tag"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowListing"
        Effect    = "Allow"
        Action    = "ec2:DescribeInstances"
        Resource  = "*"
      },
      {
        Sid       = "AllowStartStopInstancesByProjectTag"
        Effect    = "Allow"
        Action    = [
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:RebootInstances"
        ]
        Resource  = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Project" = "${aws:PrincipalTag/Project}"
          }
        }
      }
    ]
  })
}

# 2. Role IAM para o Projeto Helio
# Esta role será assumida por um usuário ou serviço e terá a tag 'Project: Helio'.
# A política acima usará esta tag para determinar quais instâncias podem ser gerenciadas.
resource "aws_iam_role" "developer_role_helio" {
  name               = "Developer-Role-Helio"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # Exemplo: se a role for assumida por uma instância EC2
          # Ou para um usuário IAM:
          # AWS = "arn:aws:iam::<YOUR_ACCOUNT_ID>:root" # Substitua pelo seu Account ID
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = "Helio"
  }
}

# 3. Anexa a política à role
resource "aws_iam_role_policy_attachment" "developer_policy_attachment" {
  role       = aws_iam_role.developer_role_helio.name
  policy_arn = aws_iam_policy.developer_project_access_policy.arn
}

# Saídas (Outputs) para facilitar a referência e verificação
output "developer_policy_arn" {
  description = "ARN of the Developer Project Access Policy"
  value       = aws_iam_policy.developer_project_access_policy.arn
}

output "developer_role_helio_arn" {
  description = "ARN of the Developer Role for Project Helio"
  value       = aws_iam_role.developer_role_helio.arn
}