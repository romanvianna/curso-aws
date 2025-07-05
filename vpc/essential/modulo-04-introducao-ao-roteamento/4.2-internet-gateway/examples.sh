#!/bin/bash

# --- Exemplo de comandos AWS CLI para manipular o Internet Gateway (IGW) ---

# Cenário: Este script demonstra como o Internet Gateway é essencial para a conectividade
# da VPC com a internet. Vamos desanexar e reanexar o IGW para observar o impacto.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Substitua pelos IDs da sua VPC e Internet Gateway
# Estes IDs devem ser obtidos de um provisionamento anterior (ex: Módulo 3.1)
VPC_ID="vpc-0abcdef1234567890" # Exemplo
IGW_ID="igw-0abcdef1234567891" # Exemplo
WEB_SERVER_PUBLIC_IP="3.88.123.45" # Substitua pelo IP público da sua instância WebServer-Lab

echo "INFO: Iniciando a manipulação do Internet Gateway na VPC ${VPC_ID}..."

# --- 1. Validar a Conectividade Existente ---
echo "INFO: Testando a conectividade atual da instância WebServer-Lab (${WEB_SERVER_PUBLIC_IP})..."
# Para este teste, você precisaria estar conectado via SSH à instância WebServer-Lab
# e executar os comandos de ping/curl de lá. Este script apenas simula a ação.
# ssh -i your-key.pem ec2-user@${WEB_SERVER_PUBLIC_IP} "ping -c 3 8.8.8.8 && curl -I https://www.google.com"

echo "Por favor, verifique manualmente a conectividade da sua instância WebServer-Lab antes de prosseguir."
read -p "Pressione Enter para continuar com a desanexação do IGW..."

# --- 2. Desanexar o Internet Gateway ---
echo "INFO: Desanexando o Internet Gateway ${IGW_ID} da VPC ${VPC_ID}..."
aws ec2 detach-internet-gateway \
  --internet-gateway-id ${IGW_ID} \
  --vpc-id ${VPC_ID}

echo "SUCCESS: Internet Gateway desanexado. Aguardando alguns segundos para propagação..."
sleep 10

echo "
--- 3. Testar a Perda de Conectividade ---"
echo "INFO: Tentando acessar a internet da instância WebServer-Lab novamente..."
echo "(Este comando deve falhar, indicando a perda de conectividade.)"
# ssh -i your-key.pem ec2-user@${WEB_SERVER_PUBLIC_IP} "ping -c 3 8.8.8.8 && curl -I https://www.google.com"

echo "Por favor, verifique manualmente a perda de conectividade da sua instância WebServer-Lab."
read -p "Pressione Enter para continuar com a reanexação do IGW..."

# --- 4. Anexar o Internet Gateway Novamente ---
echo "INFO: Anexando o Internet Gateway ${IGW_ID} de volta à VPC ${VPC_ID}..."
aws ec2 attach-internet-gateway \
  --internet-gateway-id ${IGW_ID} \
  --vpc-id ${VPC_ID}

echo "SUCCESS: Internet Gateway reanexado. Aguardando alguns segundos para propagação..."
sleep 10

echo "
--- 5. Validar a Restauração da Conectividade ---"
echo "INFO: Tentando acessar a internet da instância WebServer-Lab novamente..."
echo "(Este comando deve ter sucesso, indicando a restauração da conectividade.)"
# ssh -i your-key.pem ec2-user@${WEB_SERVER_PUBLIC_IP} "ping -c 3 8.8.8.8 && curl -I https://www.google.com"

echo "Por favor, verifique manualmente a restauração da conectividade da sua instância WebServer-Lab."

echo "-------------------------------------"
echo "Manipulação do Internet Gateway concluída!"
echo "-------------------------------------"

# --- Comandos de Limpeza ---

# Para deletar o Internet Gateway (apenas se não for mais necessário e estiver desanexado)
# aws ec2 delete-internet-gateway --internet-gateway-id ${IGW_ID}