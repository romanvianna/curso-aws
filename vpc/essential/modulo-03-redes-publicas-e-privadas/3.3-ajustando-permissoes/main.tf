# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra como criar uma IAM Role e anexá-la a uma instância EC2,
# permitindo que a instância interaja com outros serviços AWS de forma segura,
# sem a necessidade de armazenar credenciais estáticas.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.lab_vpc').
# - Uma sub-rede existente (referenciada como 'aws_subnet.lab_public_subnet' ou 'aws_subnet.lab_private_subnet').
# - Um Security Group que permita SSH (referenciado como 'aws_security_group.ssh_sg').
# - Um Key Pair EC2 já importado na AWS.

# Variáveis para configuração da instância EC2
variable "key_pair_name" {
  description = "The name of the EC2 Key Pair to use for the instance"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance (e.g., Amazon Linux 2 AMI)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Exemplo para us-east-1 Amazon Linux 2
}

variable "subnet_id" {
  description = "The ID of the subnet where the EC2 instance will be launched"
  type        = string
}

variable "security_group_ids" {
  description = "A list of Security Group IDs to associate with the EC2 instance"
  type        = list(string)
}

# 1. Criação da IAM Role para a Instância EC2
# Esta role define as permissões que a instância EC2 terá.
resource "aws_iam_role" "ec2_s3_read_only_role" {
  name = "EC2-S3-ReadOnly-Role"

  # A política de confiança permite que o serviço EC2 assuma esta role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "EC2-S3-ReadOnly-Role"
  }
}

# 2. Anexar uma Política de Permissão à IAM Role
# Anexamos a política gerenciada da AWS 'AmazonS3ReadOnlyAccess' a esta role.
# Em um ambiente de produção, uma política customizada com o menor privilégio seria preferível.
resource "aws_iam_role_policy_attachment" "s3_read_only_attachment" {
  role       = aws_iam_role.ec2_s3_read_only_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# 3. Criação do Instance Profile
# Um Instance Profile é um contêiner para uma IAM Role que pode ser anexado a uma instância EC2.
resource "aws_iam_instance_profile" "ec2_s3_read_only_profile" {
  name = "EC2-S3-ReadOnly-Profile"
  role = aws_iam_role.ec2_s3_read_only_role.name

  depends_on = [aws_iam_role.ec2_s3_read_only_role] # Garante que a role seja criada primeiro
}

# 4. Lançamento da Instância EC2 com a IAM Role Anexada
# A instância será lançada com o Instance Profile, herdando as permissões da IAM Role.
resource "aws_instance" "iam_role_test_instance" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id
  key_name      = var.key_pair_name
  vpc_security_group_ids = var.security_group_ids
  associate_public_ip_address = true # Para facilitar o acesso SSH para teste

  # Anexa o Instance Profile à instância
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_read_only_profile.name

  tags = {
    Name = "IAM-Role-Test-Instance"
  }
}

# Saídas (Outputs) para facilitar a verificação e o acesso
output "iam_role_arn" {
  description = "The ARN of the created IAM Role"
  value       = aws_iam_role.ec2_s3_read_only_role.arn
}

output "ec2_instance_id" {
  description = "The ID of the launched EC2 instance"
  value       = aws_instance.iam_role_test_instance.id
}

output "ec2_instance_public_ip" {
  description = "The Public IP of the launched EC2 instance"
  value       = aws_instance.iam_role_test_instance.public_ip
}