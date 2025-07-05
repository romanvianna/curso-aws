#!/bin/bash

# --- Exemplo de comandos AWS CLI para explorar a VPC Padrão (Default VPC) ---

# Cenário: Este script demonstra como usar a AWS CLI para inspecionar
# os componentes da sua VPC Padrão, validando os conceitos teóricos
# sobre sua configuração padrão.

# Pré-requisitos:
# - Uma Default VPC existente na sua conta e região (criada automaticamente pela AWS).

echo "--- 1. Descrevendo a VPC Padrão (Default VPC) ---"
# Encontra e exibe os detalhes da sua Default VPC.
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)

if [ -z "$DEFAULT_VPC_ID" ]; then
  echo "Nenhuma Default VPC encontrada nesta região. Certifique-se de que ela existe."
  exit 1
fi

echo "Default VPC ID: ${DEFAULT_VPC_ID}"
aws ec2 describe-vpcs --vpc-ids ${DEFAULT_VPC_ID} \
  --query "Vpcs[0].{ID:VpcId,CIDR:CidrBlock,IsDefault:IsDefault,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 2. Descrevendo as Sub-redes da Default VPC ---"
# Lista todas as sub-redes que pertencem à Default VPC.
# Observe a coluna 'MapPublicIpOnLaunch' que deve ser 'true'.
aws ec2 describe-subnets --filters Name=vpc-id,Values=${DEFAULT_VPC_ID} \
  --query "Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,AutoPublicIp:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 3. Descrevendo o Internet Gateway da Default VPC ---"
# Encontra o Internet Gateway anexado à Default VPC.
aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${DEFAULT_VPC_ID} \
  --query "InternetGateways[0].{ID:InternetGatewayId,AttachedVPC:Attachments[0].VpcId,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 4. Descrevendo as Tabelas de Rotas da Default VPC ---"
# Lista as tabelas de rotas da Default VPC. Uma delas será a principal (Main: true).
aws ec2 describe-route-tables --filters Name=vpc-id,Values=${DEFAULT_VPC_ID} \
  --query "RouteTables[*].{ID:RouteTableId,VPC_ID:VpcId,IsMain:Associations[?Main==`true`].Main | [0],Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 5. Descrevendo as Network ACLs da Default VPC ---"
# Lista as Network ACLs da Default VPC. Uma delas será a padrão (IsDefault: true).
aws ec2 describe-network-acls --filters Name=vpc-id,Values=${DEFAULT_VPC_ID} \
  --query "NetworkAcls[*].{ID:NetworkAclId,VPC_ID:VpcId,IsDefault:IsDefault,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 6. Descrevendo os Security Groups da Default VPC ---"
# Lista os Security Groups da Default VPC. Um deles será o padrão (GroupName: default).
aws ec2 describe-security-groups --filters Name=vpc-id,Values=${DEFAULT_VPC_ID} \
  --query "SecurityGroups[*].{ID:GroupId,Name:GroupName,VPC_ID:VpcId,Description:Description}" \
  --output table

echo "\nExploração da Default VPC concluída. Analise a saída para entender suas configurações padrão."