# --- Exemplo de provisionamento via Terraform (Demonstração de AWS CLI) ---

# Este arquivo demonstra como você pode executar comandos da AWS CLI
# como parte de um fluxo de trabalho do Terraform, utilizando o provisionador 'local-exec'.
# Embora o Terraform seja uma ferramenta declarativa, o 'local-exec' pode ser útil
# para tarefas específicas que ainda dependem da AWS CLI ou para validações.

# Pré-requisitos:
# - AWS CLI instalada e configurada na máquina onde o Terraform será executado.

# Configuração do provedor AWS
provider "aws" {
  region = "us-east-1" # Substitua pela sua região
}

# Exemplo de recurso Terraform: uma VPC simples
# Esta VPC será criada declarativamente pelo Terraform.
resource "aws_vpc" "cli_demo_vpc" {
  cidr_block = "10.200.0.0/16"

  tags = {
    Name = "TerraformCliDemoVPC"
  }
}

# Recurso nulo para executar comandos da AWS CLI após a criação da VPC.
# O 'local-exec' é um provisionador que executa um comando localmente.
resource "null_resource" "describe_vpc_with_cli" {
  # Garante que este recurso só será executado após a VPC ser criada.
  depends_on = [aws_vpc.cli_demo_vpc]

  provisioner "local-exec" {
    # Comando da AWS CLI para descrever a VPC recém-criada.
    # Demonstra como capturar o ID de um recurso Terraform e usá-lo na CLI.
    command = "aws ec2 describe-vpcs --vpc-ids ${aws_vpc.cli_demo_vpc.id} --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text"
    
    # Opcional: Exibir a saída do comando
    # interpreter = ["bash", "-c"]
    # command = "echo \"VPC Name from CLI: $(aws ec2 describe-vpcs --vpc-ids ${aws_vpc.cli_demo_vpc.id} --query 'Vpcs[0].Tags[?Key==`Name`].Value' --output text)\"
  }

  provisioner "local-exec" {
    # Exemplo de como usar a CLI para listar sub-redes da VPC criada
    command = "aws ec2 describe-subnets --filters Name=vpc-id,Values=${aws_vpc.cli_demo_vpc.id} --query 'Subnets[].SubnetId' --output text"
    
    # Opcional: Exibir a saída do comando
    # interpreter = ["bash", "-c"]
    # command = "echo \"Subnets in VPC from CLI: $(aws ec2 describe-subnets --filters Name=vpc-id,Values=${aws_vpc.cli_demo_vpc.id} --query 'Subnets[].SubnetId' --output text)\"
  }
}

# Saídas (Outputs) para facilitar a verificação
output "created_vpc_id" {
  description = "The ID of the VPC created by Terraform"
  value       = aws_vpc.cli_demo_vpc.id
}