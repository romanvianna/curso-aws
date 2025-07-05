# --- Exemplo de provisionamento via Terraform (Templates Avançados com Módulos) ---

# Este arquivo demonstra como usar módulos Terraform para organizar e reutilizar
# configurações de infraestrutura. Aqui, o módulo raiz chama um módulo local
# para provisionar uma VPC completa.

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

# Chamando nosso módulo VPC local
# O 'source' aponta para o diretório onde o módulo está definido.
module "my_lab_vpc" {
  source = "./modules/vpc" # Caminho para o diretório do módulo VPC

  # Passando os valores para as variáveis de entrada do módulo 'vpc'
  project_name        = "Helios" # Nome do projeto para tags
  vpc_cidr            = "10.250.0.0/16" # CIDR da VPC
  public_subnet_cidr  = "10.250.1.0/24" # CIDR da sub-rede pública
  private_subnet_cidr = "10.250.2.0/24" # CIDR da sub-rede privada (defina como null se não quiser)
  availability_zone   = "us-east-1a" # AZ para as sub-redes
}

# Usando as saídas do módulo para referência ou para outros recursos
# Estas saídas expõem os IDs dos recursos criados pelo módulo VPC.
output "lab_vpc_id" {
  description = "VPC ID returned from the module"
  value       = module.my_lab_vpc.vpc_id
}

output "lab_public_subnet_id" {
  description = "Public Subnet ID returned from the module"
  value       = module.my_lab_vpc.public_subnet_id
}

output "lab_private_subnet_id" {
  description = "Private Subnet ID returned from the module"
  value       = module.my_lab_vpc.private_subnet_id
}

output "lab_internet_gateway_id" {
  description = "Internet Gateway ID returned from the module"
  value       = module.my_lab_vpc.internet_gateway_id
}