#!/bin/bash

# --- Exemplo de comandos AWS CLI para criar e configurar Network ACLs (NACLs) ---

# Cenário: Este script demonstra a criação de uma NACL customizada e a configuração
# de regras de ALLOW e DENY, incluindo a importância das regras de portas efêmeras
# e o blacklisting de um IP específico.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS
VPC_ID="vpc-0abcdef1234567890" # Substitua pelo ID da sua VPC
PUBLIC_SUBNET_ID="subnet-0abcdef1234567891" # Substitua pelo ID da sua sub-rede pública
MY_LOCAL_IP="203.0.113.10/32" # Substitua pelo seu IP público (use um site como 'meuip.com.br')
MALICIOUS_IP="203.0.113.5/32" # IP fictício para blacklisting

echo "INFO: Iniciando a configuração da Network ACL na VPC ${VPC_ID}..."

# --- 1. Criar uma NACL customizada ---
echo "INFO: Criando Lab-Public-NACL..."
NACL_ID=$(aws ec2 create-network-acl \
  --vpc-id ${VPC_ID} \
  --query 'NetworkAcl.NetworkAclId' \
  --output text)
aws ec2 create-tags --resources ${NACL_ID} --tags Key=Name,Value=Lab-Public-NACL

echo "SUCCESS: Lab-Public-NACL criada com ID: $NACL_ID"

# --- 2. Adicionar Regras de Entrada (Inbound) ---
echo "INFO: Adicionando regras de entrada à Lab-Public-NACL..."
# Regra 90: DENY para IP malicioso (prioridade alta)
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 90 \
  --protocol all \
  --rule-action deny \
  --ingress \
  --cidr-block ${MALICIOUS_IP}

# Regra 100: ALLOW HTTP
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 100 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --port-range From=80,To=80 \
  --cidr-block 0.0.0.0/0

# Regra 110: ALLOW HTTPS
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 110 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --port-range From=443,To=443 \
  --cidr-block 0.0.0.0/0

# Regra 120: ALLOW SSH do seu IP
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 120 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --port-range From=22,To=22 \
  --cidr-block ${MY_LOCAL_IP}

# Regra 130: ALLOW portas efêmeras para tráfego de resposta de saída
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 130 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --port-range From=1024,To=65535 \
  --cidr-block 0.0.0.0/0

echo "SUCCESS: Regras de entrada adicionadas."

# --- 3. Adicionar Regras de Saída (Outbound) ---
echo "INFO: Adicionando regras de saída à Lab-Public-NACL..."
# Regra 100: ALLOW HTTP
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 100 \
  --protocol tcp \
  --rule-action allow \
  --egress \
  --port-range From=80,To=80 \
  --cidr-block 0.0.0.0/0

# Regra 110: ALLOW HTTPS
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 110 \
  --protocol tcp \
  --rule-action allow \
  --egress \
  --port-range From=443,To=443 \
  --cidr-block 0.0.0.0/0

# Regra 120: ALLOW SSH do seu IP
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 120 \
  --protocol tcp \
  --rule-action allow \
  --egress \
  --port-range From=22,To=22 \
  --cidr-block ${MY_LOCAL_IP}

# Regra 130: ALLOW portas efêmeras para tráfego de resposta de entrada
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_ID} \
  --rule-number 130 \
  --protocol tcp \
  --rule-action allow \
  --egress \
  --port-range From=1024,To=65535 \
  --cidr-block 0.0.0.0/0

echo "SUCCESS: Regras de saída adicionadas."

# --- 4. Associar a NACL à Sub-rede Pública ---
echo "INFO: Associando Lab-Public-NACL à sub-rede ${PUBLIC_SUBNET_ID}..."
# Primeiro, obtenha a associação atual da sub-rede (geralmente com a NACL padrão)
ASSOCIATION_ID=$(aws ec2 describe-network-acls \
  --filters Name=association.subnet-id,Values=${PUBLIC_SUBNET_ID} \
  --query 'NetworkAcls[0].Associations[0].NetworkAclAssociationId' \
  --output text)

aws ec2 replace-network-acl-association \
  --association-id ${ASSOCIATION_ID} \
  --network-acl-id ${NACL_ID}

echo "SUCCESS: Lab-Public-NACL associada à sub-rede ${PUBLIC_SUBNET_ID}."

echo "-------------------------------------"
echo "Configuração da Network ACL concluída!"
echo "NACL ID: ${NACL_ID}"
echo "-------------------------------------"

# --- Comandos de Limpeza ---

# Para desassociar a NACL da sub-rede e reverter para a NACL padrão da VPC
# (Você precisaria do ID da NACL padrão da sua VPC)
# aws ec2 replace-network-acl-association --association-id ${ASSOCIATION_ID} --network-acl-id <DEFAULT_NACL_ID>

# Para deletar as regras de NACL (em ordem inversa de rule-number)
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 130 --egress
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 120 --egress
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 110 --egress
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 100 --egress
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 130 --ingress
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 120 --ingress
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 110 --ingress
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 100 --ingress
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_ID} --rule-number 90 --ingress

# Para deletar a NACL customizada
# aws ec2 delete-network-acl --network-acl-id ${NACL_ID}