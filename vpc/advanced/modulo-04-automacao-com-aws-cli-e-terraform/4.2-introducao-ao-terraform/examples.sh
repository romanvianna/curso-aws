#!/bin/bash

# Inicializar o diretório Terraform
terraform init

# Validar a configuração do Terraform
terraform validate

# Gerar um plano de execução do Terraform
terraform plan

# Aplicar as mudanças do Terraform
terraform apply

# Destruir a infraestrutura do Terraform
terraform destroy
