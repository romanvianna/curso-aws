# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a configuração de uma VPC de Serviços Compartilhados
# e o compartilhamento de suas sub-redes com uma conta de aplicação usando AWS RAM.
#
# Este exemplo assume um ambiente multi-contas gerenciado por AWS Organizations.
#
# Pré-requisitos:
# - Uma AWS Organization configurada e o compartilhamento com AWS Organizations habilitado no RAM.
# - Duas contas AWS dentro da mesma Organization: uma para a Rede (proprietária da Shared Services VPC)
#   e outra para a Aplicação (consumidora da sub-rede compartilhada).

# Configuração do provedor AWS para a Conta de Rede (Proprietária da Shared Services VPC)
# Este bloco assume que as credenciais para a conta de rede estão configuradas no ambiente Terraform.
provider "aws" {
  alias  = "network_account"
  region = "us-east-1" # Defina a região da AWS
}

# Configuração do provedor AWS para a Conta de Aplicação (Consumidora da sub-rede)
# Este bloco assume que as credenciais para a conta de aplicação estão configuradas no ambiente Terraform.
provider "aws" {
  alias  = "app_account"
  region = "us-east-1" # Defina a região da AWS
}

# --- Recursos na Conta de Rede (Proprietária da Shared Services VPC) ---

# 1. VPC de Serviços Compartilhados
resource "aws_vpc" "shared_services_vpc" {
  provider   = aws.network_account
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Shared-Services-VPC"
  }
}

# 2. Sub-rede a ser Compartilhada
resource "aws_subnet" "shared_subnet_a" {
  provider          = aws.network_account
  vpc_id            = aws_vpc.shared_services_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Escolha uma AZ na sua região

  tags = {
    Name = "Shared-Subnet-A"
  }
}

# 3. Compartilhamento de Recursos (AWS RAM)
# Compartilha a sub-rede da VPC de Serviços com a conta de aplicação.
resource "aws_ram_resource_share" "subnet_share" {
  provider = aws.network_account
  name     = "VPC-Subnet-Share"
  allow_external_principals = false # Apenas para contas dentro da Organization

  tags = {
    Name = "VPC-Subnet-Share"
  }
}

resource "aws_ram_principal_association" "subnet_share_principal" {
  provider           = aws.network_account
  resource_share_arn = aws_ram_resource_share.subnet_share.arn
  principal          = "<APP_ACCOUNT_ID>" # Substitua pelo ID da sua conta de aplicação
}

resource "aws_ram_resource_association" "subnet_share_resource" {
  provider           = aws.network_account
  resource_share_arn = aws_ram_resource_share.subnet_share.arn
  resource_arn       = aws_subnet.shared_subnet_a.arn
}

# --- Recursos na Conta de Aplicação (Consumidora da sub-rede) ---

# Data Source para referenciar a sub-rede compartilhada na conta de aplicação
# Esta sub-rede aparecerá na conta de aplicação após o compartilhamento.
data "aws_subnet" "consumed_shared_subnet" {
  provider = aws.app_account
  id       = aws_subnet.shared_subnet_a.id # O ID da sub-rede é o mesmo em ambas as contas
  
  # Garante que o compartilhamento esteja ativo antes de tentar descrever a sub-rede
  depends_on = [aws_ram_principal_association.subnet_share_principal, aws_ram_resource_association.subnet_share_resource]
}

# Exemplo de como uma instância seria lançada na sub-rede compartilhada (na conta de aplicação)
# resource "aws_instance" "app_instance_in_shared_vpc" {
#   provider          = aws.app_account
#   ami               = "ami-0c55b159cbfafe1f0" # Exemplo para us-east-1 Amazon Linux 2
#   instance_type     = "t2.micro"
#   subnet_id         = data.aws_subnet.consumed_shared_subnet.id
#   key_name          = "<YOUR_KEY_PAIR_NAME>" # Substitua pelo seu Key Pair
#   associate_public_ip_address = true # Se a sub-rede compartilhada for pública
#   vpc_security_group_ids = ["<YOUR_APP_ACCOUNT_SG_ID_IN_SHARED_VPC>"] # SG criado na VPC compartilhada
#
#   tags = {
#     Name = "App-Instance-Shared-VPC"
#   }
# }

# Saídas (Outputs) para facilitar a verificação
output "shared_services_vpc_id" {
  description = "The ID of the Shared Services VPC (Network Account)"
  value       = aws_vpc.shared_services_vpc.id
  provider    = aws.network_account
}

output "shared_subnet_id" {
  description = "The ID of the shared subnet (Network Account)"
  value       = aws_subnet.shared_subnet_a.id
  provider    = aws.network_account
}

output "consumed_shared_subnet_id_in_app_account" {
  description = "The ID of the shared subnet as seen in the App Account"
  value       = data.aws_subnet.consumed_shared_subnet.id
  provider    = aws.app_account
}