#!/bin/bash

# --- Exemplo de comandos AWS CLI para criar e explorar componentes da VPC ---

# Cenário: Este script demonstra a criação de uma VPC customizada com sub-redes,
# Internet Gateway e tabelas de rotas, e como inspecionar esses componentes
# usando a AWS CLI.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS
VPC_NAME="Essential-Lab-VPC-$(date +%s)" # Nome único para a VPC
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"
AVAILABILITY_ZONE="us-east-1a" # Escolha uma AZ na sua região

echo "INFO: Iniciando o provisionamento da VPC '${VPC_NAME}' na região ${AWS_REGION}..."

# --- 1. Criar a VPC ---
echo "INFO: Criando a VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}}]" \
  --query "Vpc.VpcId" \
  --output text)

echo "SUCCESS: VPC criada com ID: $VPC_ID"

# --- 2. Criar Sub-rede Pública ---
echo "INFO: Criando a Sub-rede Pública..."
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone $AVAILABILITY_ZONE \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-Public-Subnet}]" \
  --query "Subnet.SubnetId" \
  --output text)

aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_ID \
  --map-public-ip-on-launch

echo "SUCCESS: Sub-rede Pública criada com ID: $PUBLIC_SUBNET_ID"

# --- 3. Criar Sub-rede Privada ---
echo "INFO: Criando a Sub-rede Privada..."
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone $AVAILABILITY_ZONE \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-Private-Subnet}]" \
  --query "Subnet.SubnetId" \
  --output text)

echo "SUCCESS: Sub-rede Privada criada com ID: $PRIVATE_SUBNET_ID"

# --- 4. Criar e Anexar Internet Gateway ---
echo "INFO: Criando e anexando o Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_NAME}-IGW}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

echo "SUCCESS: Internet Gateway criado e anexado: $IGW_ID"

# --- 5. Criar Tabela de Rotas Pública e Associar ---
echo "INFO: Criando Tabela de Rotas Pública..."
PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-Public-RT}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID > /dev/null

aws ec2 associate-route-table \
  --subnet-id $PUBLIC_SUBNET_ID \
  --route-table-id $PUBLIC_RT_ID > /dev/null

echo "SUCCESS: Tabela de Rotas Pública criada e associada: $PUBLIC_RT_ID"

# --- 6. Criar Tabela de Rotas Privada e Associar ---
echo "INFO: Criando Tabela de Rotas Privada..."
PRIVATE_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-Private-RT}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 associate-route-table \
  --subnet-id $PRIVATE_SUBNET_ID \
  --route-table-id $PRIVATE_RT_ID > /dev/null

echo "SUCCESS: Tabela de Rotas Privada criada e associada: $PRIVATE_RT_ID"

echo "-------------------------------------"
echo "Provisionamento da VPC concluído!"
echo "VPC ID: ${VPC_ID}"
echo "Public Subnet ID: ${PUBLIC_SUBNET_ID}"
echo "Private Subnet ID: ${PRIVATE_SUBNET_ID}"
echo "Internet Gateway ID: ${IGW_ID}"
echo "Public Route Table ID: ${PUBLIC_RT_ID}"
echo "Private Route Table ID: ${PRIVATE_RT_ID}"
echo "-------------------------------------"

# --- Comandos de Limpeza (destroy_vpc.sh) ---
# Para limpar os recursos criados por este script, você pode usar o seguinte script:
# Salve como destroy_vpc.sh e execute com o VPC_ID como argumento:
# ./destroy_vpc.sh <VPC_ID>

# #!/bin/bash

# # Script imperativo para destruir uma VPC criada pelo provision_vpc.sh.

# set -e # Encerra o script imediatamente se um comando falhar

# if [ -z "$1" ]; then
#   echo "Uso: $0 <VPC_ID>"
#   exit 1
# fi

# VPC_ID=$1

# echo "INFO: Iniciando a destruição da VPC ${VPC_ID}..."

# # 1. Desassociar e deletar a tabela de rotas (se não for a principal)
# ASSOCIATIONS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --query "RouteTables[].Associations[?Main != `true`].RouteTableAssociationId" --output text)
# for ASSOC_ID in $ASSOCIATIONS; do
#   echo "INFO: Desassociando tabela de rotas ${ASSOC_ID}..."
#   aws ec2 disassociate-route-table --association-id $ASSOC_ID
# done

# # Encontre e delete as rotas (exceto a rota local)
# ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --query "RouteTables[].RouteTableId" --output text)
# for RT_ID in $ROUTE_TABLE_IDS; do
#   echo "INFO: Deletando rotas da tabela ${RT_ID}..."
#   ROUTES=$(aws ec2 describe-route-tables --route-table-ids ${RT_ID} --query "RouteTables[0].Routes[?Origin != `CreateRouteTable`].DestinationCidrBlock" --output text)
#   for DEST_CIDR in $ROUTES; do
#     echo "INFO: Deletando rota ${DEST_CIDR} da tabela ${RT_ID}"
#     aws ec2 delete-route --route-table-id ${RT_ID} --destination-cidr-block ${DEST_CIDR}
#   done
#   # Se a tabela de rotas não for a principal, delete-a
#   IS_MAIN=$(aws ec2 describe-route-tables --route-table-ids ${RT_ID} --query "RouteTables[0].Associations[0].Main" --output text)
#   if [ "$IS_MAIN" != "true" ]; then
#     echo "INFO: Deletando tabela de rotas ${RT_ID}..."
#     aws ec2 delete-route-table --route-table-id ${RT_ID}
#   fi
# done

# # 2. Deletar sub-redes
# SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --query "Subnets[].SubnetId" --output text)
# for SUBNET_ID in $SUBNET_IDS; do
#   echo "INFO: Deletando sub-rede ${SUBNET_ID}..."
#   aws ec2 delete-subnet --subnet-id $SUBNET_ID
# done

# # 3. Desanexar e deletar Internet Gateway
# IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${VPC_ID}" --query "InternetGateways[0].InternetGatewayId" --output text)
# if [ -n "$IGW_ID" ]; then
#   echo "INFO: Desanexando Internet Gateway ${IGW_ID} da VPC ${VPC_ID}..."
#   aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
#   echo "INFO: Deletando Internet Gateway ${IGW_ID}..."
#   aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
# else
#   echo "INFO: Nenhum Internet Gateway encontrado para a VPC ${VPC_ID}."
# fi

# # 4. Deletar a VPC
# echo "INFO: Deletando VPC ${VPC_ID}..."
# aws ec2 delete-vpc --vpc-id $VPC_ID

# echo "SUCCESS: VPC ${VPC_ID} e seus recursos associados foram deletados."