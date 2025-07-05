#!/bin/bash

# --- Exemplo de comandos AWS CLI para manipular Tabelas de Rotas ---

# Cenário: Este script demonstra como inspecionar e manipular tabelas de rotas
# em uma VPC, incluindo a criação de rotas e associações de sub-rede.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Substitua pelos IDs da sua VPC, sub-redes e Internet Gateway
# Estes IDs devem ser obtidos de um provisionamento anterior (ex: Módulo 3.1)
VPC_ID="vpc-0abcdef1234567890" # Exemplo
PUBLIC_SUBNET_ID="subnet-0abcdef1234567891" # Exemplo
PRIVATE_SUBNET_ID="subnet-0abcdef1234567892" # Exemplo
IGW_ID="igw-0abcdef1234567893" # Exemplo

echo "INFO: Iniciando a manipulação de Tabelas de Rotas na VPC ${VPC_ID}..."

# --- 1. Descrever as Tabelas de Rotas da VPC ---
echo "INFO: Descrevendo todas as tabelas de rotas na VPC ${VPC_ID}..."
aws ec2 describe-route-tables --filters Name=vpc-id,Values=${VPC_ID} \
  --query "RouteTables[*].{ID:RouteTableId,VPC_ID:VpcId,IsMain:Associations[?Main==`true`].Main | [0],Name:Tags[?Key==`Name`].Value | [0],Routes:Routes}" \
  --output json

# --- 2. Identificar a Tabela de Rotas Principal (Main Route Table) ---
echo "INFO: Identificando a Tabela de Rotas Principal..."
MAIN_RT_ID=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=${VPC_ID} Name=association.main,Values=true --query "RouteTables[0].RouteTableId" --output text)

echo "Main Route Table ID: ${MAIN_RT_ID}"

# --- 3. Criar uma Tabela de Rotas Customizada (se ainda não tiver uma pública) ---
echo "INFO: Criando uma Tabela de Rotas Customizada para sub-rede pública..."
CUSTOM_PUBLIC_RT_ID=$(aws ec2 create-route-table \\
  --vpc-id ${VPC_ID} \\
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=Custom-Public-RT}]' \\
  --query 'RouteTable.RouteTableId' \\
  --output text)

echo "SUCCESS: Tabela de Rotas Customizada criada: ${CUSTOM_PUBLIC_RT_ID}"

# --- 4. Adicionar uma Rota para o Internet Gateway na Tabela Customizada ---
echo "INFO: Adicionando rota padrão para a internet na Tabela Customizada ${CUSTOM_PUBLIC_RT_ID}..."
aws ec2 create-route \\
  --route-table-id ${CUSTOM_PUBLIC_RT_ID} \\
  --destination-cidr-block 0.0.0.0/0 \\
  --gateway-id ${IGW_ID} > /dev/null

echo "SUCCESS: Rota para o Internet Gateway adicionada."

# --- 5. Associar a Tabela de Rotas Customizada à Sub-rede Pública ---
echo "INFO: Associando a Tabela Customizada ${CUSTOM_PUBLIC_RT_ID} à Sub-rede Pública ${PUBLIC_SUBNET_ID}..."
# Primeiro, obtenha a associação atual da sub-rede
PUBLIC_SUBNET_ASSOC_ID=$(aws ec2 describe-route-tables \\
  --filters Name=association.subnet-id,Values=${PUBLIC_SUBNET_ID} \\
  --query 'RouteTables[0].Associations[0].RouteTableAssociationId' \\
  --output text)

aws ec2 replace-route-table-association \\
  --association-id ${PUBLIC_SUBNET_ASSOC_ID} \\
  --route-table-id ${CUSTOM_PUBLIC_RT_ID}

echo "SUCCESS: Sub-rede Pública ${PUBLIC_SUBNET_ID} agora associada à Tabela Customizada ${CUSTOM_PUBLIC_RT_ID}."

echo "-------------------------------------"
echo "Manipulação de Tabelas de Rotas concluída!"
echo "-------------------------------------"

# --- Comandos de Limpeza ---

# Para reverter a associação da sub-rede pública para a tabela principal
# aws ec2 replace-route-table-association --association-id ${PUBLIC_SUBNET_ASSOC_ID} --route-table-id ${MAIN_RT_ID}

# Para deletar a rota criada na tabela customizada
# aws ec2 delete-route --route-table-id ${CUSTOM_PUBLIC_RT_ID} --destination-cidr-block 0.0.0.0/0

# Para deletar a tabela de rotas customizada
# aws ec2 delete-route-table --route-table-id ${CUSTOM_PUBLIC_RT_ID}