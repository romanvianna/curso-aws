#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Demonstrar a criação e configuração de Security Groups e Network ACLs
# para uma arquitetura de 3 camadas (Web, App, DB).

# Pré-requisitos:
# 1. Uma VPC existente (substitua <VPC_ID>).
# 2. IDs das sub-redes (Web, App, DB) para associar as NACLs.

# Variáveis de exemplo (substitua pelos seus IDs/CIDRs reais)
# VPC_ID="vpc-0abcdef1234567890"
# SUBNET_WEB_ID="subnet-0abcdef1234567890"
# SUBNET_APP_ID="subnet-0abcdef1234567891"
# SUBNET_DB_ID="subnet-0abcdef1234567892"
# SUBNET_APP_CIDR="10.0.2.0/24"
# SUBNET_DB_CIDR="10.0.3.0/24"
# MY_LOCAL_IP="203.0.113.10/32" # Seu IP público

echo "--- Criando Security Groups ---"

# Security Group para a Camada Web
WEB_SG_ID=$(aws ec2 create-security-group \
  --group-name WebSG \
  --description "Security Group for Web Layer" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)
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
aws ec2 authorize-security-group-ingress \
  --group-id ${WEB_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

echo "WebSG criado: $WEB_SG_ID"

# Security Group para a Camada de Aplicação
APP_SG_ID=$(aws ec2 create-security-group \
  --group-name AppSG \
  --description "Security Group for Application Layer" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id ${APP_SG_ID} \
  --protocol tcp \
  --port 8080 \
  --source-group ${WEB_SG_ID} # Permite acesso apenas do WebSG
aws ec2 authorize-security-group-ingress \
  --group-id ${APP_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

echo "AppSG criado: $APP_SG_ID"

# Security Group para a Camada de Banco de Dados
DB_SG_ID=$(aws ec2 create-security-group \
  --group-name DBSG \
  --description "Security Group for Database Layer" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id ${DB_SG_ID} \
  --protocol tcp \
  --port 3306 \
  --source-group ${APP_SG_ID} # Permite acesso apenas do AppSG
aws ec2 authorize-security-group-ingress \
  --group-id ${DB_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

echo "DBSG criado: $DB_SG_ID"

echo "--- Criando Network ACLs ---"

# Network ACL para a Sub-rede do Banco de Dados (DB-NACL)
DB_NACL_ID=$(aws ec2 create-network-acl \
  --vpc-id ${VPC_ID} \
  --query 'NetworkAcl.NetworkAclId' \
  --output text)
aws ec2 create-tags --resources ${DB_NACL_ID} --tags Key=Name,Value=DB-NACL

# Regras de Entrada (Inbound) para DB-NACL
aws ec2 create-network-acl-entry \
  --network-acl-id ${DB_NACL_ID} \
  --rule-number 100 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --port-range From=3306,To=3306 \
  --cidr-block ${SUBNET_APP_CIDR}
aws ec2 create-network-acl-entry \
  --network-acl-id ${DB_NACL_ID} \
  --rule-number 110 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --port-range From=1024,To=65535 \
  --cidr-block ${SUBNET_APP_CIDR}
aws ec2 create-network-acl-entry \
  --network-acl-id ${DB_NACL_ID} \
  --rule-number 120 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --port-range From=22,To=22 \
  --cidr-block ${MY_LOCAL_IP}

# Regras de Saída (Outbound) para DB-NACL
aws ec2 create-network-acl-entry \
  --network-acl-id ${DB_NACL_ID} \
  --rule-number 100 \
  --protocol tcp \
  --rule-action allow \
  --egress \
  --port-range From=3306,To=3306 \
  --cidr-block ${SUBNET_APP_CIDR}
aws ec2 create-network-acl-entry \
  --network-acl-id ${DB_NACL_ID} \
  --rule-number 110 \
  --protocol tcp \
  --rule-action allow \
  --egress \
  --port-range From=1024,To=65535 \
  --cidr-block ${SUBNET_APP_CIDR}
aws ec2 create-network-acl-entry \
  --network-acl-id ${DB_NACL_ID} \
  --rule-number 120 \
  --protocol tcp \
  --rule-action allow \
  --egress \
  --port-range From=22,To=22 \
  --cidr-block ${MY_LOCAL_IP}

echo "DB-NACL criado: $DB_NACL_ID"

# Associar DB-NACL à Sub-rede do Banco de Dados
aws ec2 replace-network-acl-association \
  --association-id $(aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=${SUBNET_DB_ID}" --query "NetworkAcls[0].Associations[0].NetworkAclAssociationId" --output text) \
  --network-acl-id ${DB_NACL_ID}

echo "DB-NACL associado à sub-rede ${SUBNET_DB_ID}"

# Exemplo de Blacklisting em NACL Pública (assumindo que SUBNET_WEB_ID tem uma NACL padrão)
# Obtenha o ID da NACL padrão da sub-rede web
WEB_NACL_ID=$(aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=${SUBNET_WEB_ID}" --query "NetworkAcls[0].NetworkAclId" --output text)

# Adiciona regra de DENY para IP malicioso na NACL da sub-rede web
aws ec2 create-network-acl-entry \
  --network-acl-id ${WEB_NACL_ID} \
  --rule-number 90 \
  --protocol all \
  --rule-action deny \
  --ingress \
  --cidr-block 203.0.113.5/32

echo "Regra de DENY para 203.0.113.5/32 adicionada à NACL da sub-rede web: ${WEB_NACL_ID}"

echo "Configuração de Security Groups e Network ACLs concluída."

# --- Comandos de Limpeza ---

# Para deletar as regras de NACL (em ordem inversa)
# aws ec2 delete-network-acl-entry --network-acl-id ${DB_NACL_ID} --rule-number 120 --egress
# aws ec2 delete-network-acl-entry --network-acl-id ${DB_NACL_ID} --rule-number 110 --egress
# aws ec2 delete-network-acl-entry --network-acl-id ${DB_NACL_ID} --rule-number 100 --egress
# aws ec2 delete-network-acl-entry --network-acl-id ${DB_NACL_ID} --rule-number 120 --ingress
# aws ec2 delete-network-acl-entry --network-acl-id ${DB_NACL_ID} --rule-number 110 --ingress
# aws ec2 delete-network-acl-entry --network-acl-id ${DB_NACL_ID} --rule-number 100 --ingress

# Para deletar a NACL customizada
# aws ec2 delete-network-acl --network-acl-id ${DB_NACL_ID}

# Para deletar os Security Groups
# aws ec2 delete-security-group --group-id ${WEB_SG_ID}
# aws ec2 delete-security-group --group-id ${APP_SG_ID}
# aws ec2 delete-security-group --group-id ${DB_SG_ID}