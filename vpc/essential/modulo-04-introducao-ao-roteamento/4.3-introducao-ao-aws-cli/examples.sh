#!/bin/bash

# --- Exemplo de comandos AWS CLI para inspecionar componentes da VPC ---

# Cenário: Este script demonstra como usar a AWS CLI para realizar operações de "leitura" (describe)
# em componentes da VPC, como VPCs, sub-redes, Internet Gateways, tabelas de rotas e Security Groups.
# Ele também mostra como usar filtros e queries para obter informações específicas.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS
# Substitua pelo nome da sua VPC criada no Módulo 3.1
VPC_NAME="Essential-Custom-VPC" # Ou o nome que você deu à sua VPC

echo "INFO: Iniciando a exploração de componentes da VPC via AWS CLI na região ${AWS_REGION}..."

# --- 1. Descrever a VPC ---
echo "
--- Descrevendo a VPC (filtrando pelo nome) ---"
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${VPC_NAME}" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [ -z "$VPC_ID" ]; then
  echo "ERRO: VPC com nome '${VPC_NAME}' não encontrada. Verifique o nome ou crie a VPC primeiro."
  exit 1
fi

echo "VPC ID para ${VPC_NAME}: ${VPC_ID}"
aws ec2 describe-vpcs --vpc-ids ${VPC_ID} \
  --query "Vpcs[0].{ID:VpcId,CIDR:CidrBlock,IsDefault:IsDefault,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

# --- 2. Descrever as Sub-redes da VPC ---
echo "
--- Descrevendo as Sub-redes na VPC ${VPC_ID} ---"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,AutoPublicIp:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`].Value | [0]}' \
  --output table

# --- 3. Descrever o Internet Gateway da VPC ---
echo "
--- Descrevendo o Internet Gateway na VPC ${VPC_ID} ---"
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
  --query "InternetGateways[0].{ID:InternetGatewayId,AttachedVPC:Attachments[0].VpcId,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

# --- 4. Descrever as Tabelas de Rotas da VPC ---
echo "
--- Descrevendo as Tabelas de Rotas na VPC ${VPC_ID} ---"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query "RouteTables[*].{ID:RouteTableId,VPC_ID:VpcId,IsMain:Associations[?Main==`true`].Main | [0],Name:Tags[?Key==`Name`].Value | [0],Routes:Routes}" \
  --output json # Usando JSON para mostrar a estrutura completa das rotas

# --- 5. Descrever as Network ACLs da VPC ---
echo "
--- Descrevendo as Network ACLs na VPC ${VPC_ID} ---"
aws ec2 describe-network-acls --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query "NetworkAcls[*].{ID:NetworkAclId,VPC_ID:VpcId,IsDefault:IsDefault,Name:Tags[?Key==`Name`].Value | [0],Entries:Entries}" \
  --output json # Usando JSON para mostrar as regras de entrada/saída

# --- 6. Descrever os Security Groups da VPC ---
echo "
--- Descrevendo os Security Groups na VPC ${VPC_ID} ---"
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${VPC_ID}" \
  --query "SecurityGroups[*].{ID:GroupId,Name:GroupName,VPC_ID:VpcId,Description:Description,IpPermissions:IpPermissions}" \
  --output json # Usando JSON para mostrar as regras de permissão

echo "
-------------------------------------"
echo "Exploração de componentes da VPC via AWS CLI concluída!"
echo "-------------------------------------"

# --- Exemplo de Operação de Escrita (Adicionar uma Tag à VPC) ---
echo "
--- Exemplo de Operação de Escrita: Adicionando uma Tag à VPC ---"
aws ec2 create-tags --resources ${VPC_ID} --tags "Key=ManagedBy,Value=CLI-Lab"

echo "Tag 'ManagedBy: CLI-Lab' adicionada à VPC ${VPC_ID}."

# Verifique a nova tag
aws ec2 describe-vpcs --vpc-ids ${VPC_ID} --query "Vpcs[0].Tags" --output table

# --- Comandos de Limpeza (Opcional) ---

# Para remover a tag adicionada
# aws ec2 delete-tags --resources ${VPC_ID} --tags "Key=ManagedBy,Value=CLI-Lab"