#!/bin/bash

# --- Exemplo de provisionamento via Terraform (Comandos Básicos) ---

# Este script demonstra o fluxo de trabalho básico do Terraform:
# init, validate, plan, apply e destroy.

# Pré-requisitos:
# 1. Terraform CLI instalado.
# 2. Arquivos .tf configurados no diretório atual.
# 3. AWS CLI configurada com credenciais de acesso.

# Variáveis de exemplo (se necessário, para passar para o Terraform via -var)
# export TF_VAR_region="us-east-1"
# export TF_VAR_vpc_cidr="10.0.0.0/16"

echo "--- 1. Inicializando o diretório Terraform ---"
# Baixa os provedores necessários e inicializa o backend.
terraform init

if [ $? -ne 0 ]; then
  echo "ERRO: terraform init falhou. Verifique a configuração."
  exit 1
fi

echo "--- 2. Validando a configuração do Terraform ---"
# Verifica a sintaxe e a validade dos arquivos .tf.
terraform validate

if [ $? -ne 0 ]; then
  echo "ERRO: terraform validate falhou. Corrija os erros de sintaxe."
  exit 1
fi

echo "--- 3. Gerando um plano de execução do Terraform ---"
# Mostra o que o Terraform fará antes de aplicar as mudanças.
# Salva o plano em um arquivo para ser usado no apply (boa prática).
terraform plan -out tfplan.out

if [ $? -ne 0 ]; then
  echo "ERRO: terraform plan falhou. Verifique o plano e as dependências."
  exit 1
fi

echo "--- 4. Aplicando as mudanças do Terraform ---"
# Executa as ações definidas no plano.
# Use -auto-approve com cautela em ambientes de produção.
terraform apply tfplan.out

if [ $? -ne 0 ]; then
  echo "ERRO: terraform apply falhou. Verifique os logs."
  exit 1
fi

echo "SUCCESS: Infraestrutura provisionada com sucesso!"

echo "\n--- 5. Destruindo a infraestrutura do Terraform (Opcional) ---"
# Remove todos os recursos gerenciados pelo Terraform.
# Use com extrema cautela em ambientes de produção!
read -p "Deseja destruir a infraestrutura? (y/N): " CONFIRM_DESTROY
if [[ "$CONFIRM_DESTROY" =~ ^[yY]$ ]]; then
  terraform destroy -auto-approve
  if [ $? -ne 0 ]; then
    echo "ERRO: terraform destroy falhou."
    exit 1
  fi
  echo "SUCCESS: Infraestrutura destruída com sucesso!"
else
  echo "Destruição cancelada."
fi