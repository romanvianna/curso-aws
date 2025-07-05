#!/bin/bash

# --- Exemplo de comandos AWS CLI para criar e configurar Security Groups ---

# Cenário: Este script demonstra a criação de Security Groups para uma arquitetura
# de duas camadas (Web e Banco de Dados), utilizando referências de Security Group
# para permitir comunicação segura entre elas.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS
VPC_ID="vpc-0abcdef1234567890" # Substitua pelo ID da sua VPC
MY_LOCAL_IP="203.0.113.10/32" # Substitua pelo seu IP público (use um site como 'meuip.com.br')

echo "INFO: Iniciando a configuração dos Security Groups na VPC ${VPC_ID}..."

# --- 1. Criar Security Group para Servidor Web (WebServer-SG) ---
echo "INFO: Criando WebServer-SG..."
WEB_SG_ID=$(aws ec2 create-security-group \
  --group-name WebServer-SG \
  --description "Security Group for Web Servers" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)

# Regras de Entrada (Inbound) para WebServer-SG
# Permite HTTP (80) e HTTPS (443) de qualquer lugar
aws ec2 authorize-security-group-ingress \
  --group-id ${WEB_SG_ID} \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress \
  --group-id ${WEB_SG_ID} \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
# Permite SSH (22) apenas do seu IP local
aws ec2 authorize-security-group-ingress \
  --group-id ${WEB_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

echo "SUCCESS: WebServer-SG criado com ID: $WEB_SG_ID"

# --- 2. Criar Security Group para Servidor de Banco de Dados (DBServer-SG) ---
echo "INFO: Criando DBServer-SG..."
DB_SG_ID=$(aws ec2 create-security-group \
  --group-name DBServer-SG \
  --description "Security Group for Database Servers" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)

# Regras de Entrada (Inbound) para DBServer-SG
# Permite MySQL/Aurora (3306) APENAS do WebServer-SG (referência de SG)
aws ec2 authorize-security-group-ingress \
  --group-id ${DB_SG_ID} \
  --protocol tcp \
  --port 3306 \
  --source-group ${WEB_SG_ID}
# Permite SSH (22) apenas do seu IP local
aws ec2 authorize-security-group-ingress \
  --group-id ${DB_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

echo "SUCCESS: DBServer-SG criado com ID: $DB_SG_ID"

echo "-------------------------------------"
echo "Configuração de Security Groups concluída!"
echo "WebServer-SG ID: ${WEB_SG_ID}"
echo "DBServer-SG ID: ${DB_SG_ID}"
echo "-------------------------------------"

# --- Comandos de Limpeza ---

# Para deletar os Security Groups (deve ser feito na ordem inversa de dependência)
# Primeiro, revogue as regras que referenciam o SG que você quer deletar
# aws ec2 revoke-security-group-ingress --group-id ${DB_SG_ID} --protocol tcp --port 3306 --source-group ${WEB_SG_ID}
# aws ec2 delete-security-group --group-id ${DB_SG_ID}
# aws ec2 delete-security-group --group-id ${WEB_SG_ID}