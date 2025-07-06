#!/bin/bash

# --- Exemplo de comandos AWS CLI para Automação em Escala com GitOps ---

# Cenário: Este script não executa um pipeline de CI/CD completo, pois isso
# requer um ambiente Git (GitHub, GitLab) e um runner de CI/CD (GitHub Actions, Jenkins).
# No entanto, ele demonstra os comandos AWS CLI que seriam executados dentro de um pipeline
# de GitOps para gerenciar a infraestrutura Terraform.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Assumimos que o código Terraform está no diretório atual
TERRAFORM_DIR="."

echo "INFO: Simulando execução de comandos AWS CLI em um pipeline de GitOps..."

# --- Passo 1: Configurar Credenciais AWS (Simulação de um CI/CD Runner) ---
echo "INFO: Configurando credenciais AWS (simulação)..."
# Em um pipeline real, isso seria feito de forma segura via OIDC ou variáveis de ambiente
# export AWS_ACCESS_KEY_ID="AKIA..."
# export AWS_SECRET_ACCESS_KEY="..."
# export AWS_SESSION_TOKEN="..."

# Para este exemplo, vamos apenas verificar se a CLI está configurada
aws sts get-caller-identity --query Account --output text > /dev/null
echo "SUCCESS: Credenciais AWS simuladas configuradas."

# --- Passo 2: Terraform Init ---
echo "INFO: Executando 'terraform init'..."
terraform -chdir=${TERRAFORM_DIR} init

echo "SUCCESS: Terraform inicializado."

# --- Passo 3: Terraform Validate ---
echo "INFO: Executando 'terraform validate'..."
terraform -chdir=${TERRAFORM_DIR} validate

echo "SUCCESS: Terraform validado."

# --- Passo 4: Terraform Plan (para Pull Requests) ---
echo "INFO: Executando 'terraform plan' (simulando um Pull Request)..."
# O output do plan seria capturado e postado como comentário no PR
terraform -chdir=${TERRAFORM_DIR} plan -no-color

echo "SUCCESS: Terraform plan gerado."

# --- Passo 5: Terraform Apply (para Merge no Main) ---
echo "INFO: Executando 'terraform apply' (simulando merge no main)..."
# Em um pipeline real, isso seria condicional ao merge no branch principal
read -p "Deseja executar 'terraform apply -auto-approve' agora? (y/N): " CONFIRM_APPLY
if [[ "$CONFIRM_APPLY" =~ ^[yY]$ ]]; then
  terraform -chdir=${TERRAFORM_DIR} apply -auto-approve
  echo "SUCCESS: Terraform apply executado."
else
  echo "Terraform apply ignorado."
fi

echo "-------------------------------------"
echo "Simulação de comandos GitOps concluída!"
echo "-------------------------------------"

# --- Comandos de Limpeza (se você executou o apply) ---
# read -p "Deseja executar 'terraform destroy -auto-approve' para limpar os recursos? (y/N): " CONFIRM_DESTROY
# if [[ "$CONFIRM_DESTROY" =~ ^[yY]$ ]]; then
#   terraform -chdir=${TERRAFORM_DIR} destroy -auto-approve
#   echo "SUCCESS: Terraform destroy executado."
# else
#   echo "Terraform destroy ignorado."
# fi