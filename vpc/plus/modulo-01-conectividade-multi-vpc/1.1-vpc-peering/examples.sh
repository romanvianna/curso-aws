#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar VPC Peering ---

# Cenário: Este script demonstra como criar duas VPCs, estabelecer uma conexão
# de VPC Peering entre elas e configurar as tabelas de rotas para permitir
# a comunicação privada.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# VPC A (Requester)
VPC_A_NAME="VPC-Dev-$(date +%s)"
VPC_A_CIDR="10.10.0.0/16"
VPC_A_SUBNET_CIDR="10.10.1.0/24"
VPC_A_AZ="us-east-1a"

# VPC B (Accepter)
VPC_B_NAME="VPC-Data-$(date +%s)"
VPC_B_CIDR="10.20.0.0/16"
VPC_B_SUBNET_CIDR="10.20.1.0/24"
VPC_B_AZ="us-east-1a"

# Key Pair para as instâncias (substitua pelo seu)
KEY_PAIR_NAME="my-ec2-key"
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
MY_LOCAL_IP="203.0.113.10/32" # Substitua pelo seu IP público

echo "INFO: Iniciando a configuração de VPC Peering..."

# --- 1. Criar VPC A (Requester) ---
echo "INFO: Criando VPC A (${VPC_A_NAME})..."
VPC_A_ID=$(aws ec2 create-vpc \
  --cidr-block ${VPC_A_CIDR} \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_A_NAME}}]" \
  --query 'Vpc.VpcId' \
  --output text)

VPC_A_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${VPC_A_ID} \
  --cidr-block ${VPC_A_SUBNET_CIDR} \
  --availability-zone ${VPC_A_AZ} \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_A_NAME}-Subnet}]" \
  --query 'Subnet.SubnetId' \
  --output text)

VPC_A_IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_A_NAME}-IGW}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
aws ec2 attach-internet-gateway --vpc-id ${VPC_A_ID} --internet-gateway-id ${VPC_A_IGW_ID}

VPC_A_RT_ID=$(aws ec2 create-route-table \
  --vpc-id ${VPC_A_ID} \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_A_NAME}-RT}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
aws ec2 create-route --route-table-id ${VPC_A_RT_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${VPC_A_IGW_ID} > /dev/null
aws ec2 associate-route-table --subnet-id ${VPC_A_SUBNET_ID} --route-table-id ${VPC_A_RT_ID} > /dev/null

# Security Group para Instância A
VPC_A_SG_ID=$(aws ec2 create-security-group \
  --group-name ${VPC_A_NAME}-SG \
  --description "SG for ${VPC_A_NAME}" \
  --vpc-id ${VPC_A_ID} \
  --query 'GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_A_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

# Instância A
INSTANCE_A_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${VPC_A_SUBNET_ID} \
  --security-group-ids ${VPC_A_SG_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instance-Dev}]' \
  --query 'Instances[0].InstanceId' \
  --output text)
aws ec2 wait instance-running --instance-ids ${INSTANCE_A_ID}
INSTANCE_A_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_A_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
INSTANCE_A_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_A_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "SUCCESS: VPC A e Instância Dev criadas. Instância A IP Privado: ${INSTANCE_A_PRIVATE_IP}, IP Público: ${INSTANCE_A_PUBLIC_IP}"

# --- 2. Criar VPC B (Accepter) ---
echo "INFO: Criando VPC B (${VPC_B_NAME})..."
VPC_B_ID=$(aws ec2 create-vpc \
  --cidr-block ${VPC_B_CIDR} \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_B_NAME}}]" \
  --query 'Vpc.VpcId' \
  --output text)

VPC_B_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${VPC_B_ID} \
  --cidr-block ${VPC_B_SUBNET_CIDR} \
  --availability-zone ${VPC_B_AZ} \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_B_NAME}-Subnet}]" \
  --query 'Subnet.SubnetId' \
  --output text)

VPC_B_IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_B_NAME}-IGW}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
aws ec2 attach-internet-gateway --vpc-id ${VPC_B_ID} --internet-gateway-id ${VPC_B_IGW_ID}

VPC_B_RT_ID=$(aws ec2 create-route-table \
  --vpc-id ${VPC_B_ID} \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_B_NAME}-RT}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
aws ec2 create-route --route-table-id ${VPC_B_RT_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${VPC_B_IGW_ID} > /dev/null
aws ec2 associate-route-table --subnet-id ${VPC_B_SUBNET_ID} --route-table-id ${VPC_B_RT_ID} > /dev/null

# Security Group para Instância B
VPC_B_SG_ID=$(aws ec2 create-security-group \
  --group-name ${VPC_B_NAME}-SG \
  --description "SG for ${VPC_B_NAME}" \
  --vpc-id ${VPC_B_ID} \
  --query 'GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_B_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

# Instância B
INSTANCE_B_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${VPC_B_SUBNET_ID} \
  --security-group-ids ${VPC_B_SG_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instance-Data}]' \
  --query 'Instances[0].InstanceId' \
  --output text)
aws ec2 wait instance-running --instance-ids ${INSTANCE_B_ID}
INSTANCE_B_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_B_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
INSTANCE_B_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_B_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "SUCCESS: VPC B e Instância Data criadas. Instância B IP Privado: ${INSTANCE_B_PRIVATE_IP}, IP Público: ${INSTANCE_B_PUBLIC_IP}"

# --- 3. Criar a Conexão de Peering ---
echo "INFO: Criando conexão de Peering entre ${VPC_A_ID} e ${VPC_B_ID}..."
PEERING_CONNECTION_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id ${VPC_A_ID} \
  --peer-vpc-id ${VPC_B_ID} \
  --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=Dev-to-Data-Peering}]" \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

echo "SUCCESS: Conexão de Peering solicitada: ${PEERING_CONNECTION_ID}. Aguardando aceitação..."

# Aceitar a conexão de peering (assumindo que a mesma conta é a aceitante)
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id ${PEERING_CONNECTION_ID}

echo "INFO: Conexão de Peering aceita."

# --- 4. Atualizar as Tabelas de Rotas ---
echo "INFO: Atualizando tabelas de rotas..."

# Rota na VPC A para VPC B
aws ec2 create-route \
  --route-table-id ${VPC_A_RT_ID} \
  --destination-cidr-block ${VPC_B_CIDR} \
  --vpc-peering-connection-id ${PEERING_CONNECTION_ID} > /dev/null

echo "Rota adicionada na VPC A para VPC B."

# Rota na VPC B para VPC A
aws ec2 create-route \
  --route-table-id ${VPC_B_RT_ID} \
  --destination-cidr-block ${VPC_A_CIDR} \
  --vpc-peering-connection-id ${PEERING_CONNECTION_ID} > /dev/null

echo "Rota adicionada na VPC B para VPC A."

# --- 5. Atualizar Security Groups para permitir comunicação via Peering ---
echo "INFO: Atualizando Security Groups..."

# Permite ICMP (ping) e SSH da VPC A para a Instância B
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_B_SG_ID} \
  --protocol icmp \
  --port -1 \
  --cidr ${VPC_A_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_B_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${VPC_A_CIDR}

echo "Security Group da Instância B atualizado."

# Permite ICMP (ping) e SSH da VPC B para a Instância A (se necessário para teste bidirecional)
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_A_SG_ID} \
  --protocol icmp \
  --port -1 \
  --cidr ${VPC_B_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_A_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${VPC_B_CIDR}

echo "Security Group da Instância A atualizado."

echo "-------------------------------------"
echo "Configuração de VPC Peering concluída!"
echo "VPC A ID: ${VPC_A_ID}"
echo "VPC B ID: ${VPC_B_ID}"
echo "Peering Connection ID: ${PEERING_CONNECTION_ID}"
echo "Instância Dev IP Privado: ${INSTANCE_A_PRIVATE_IP}"
echo "Instância Data IP Privado: ${INSTANCE_B_PRIVATE_IP}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação) ---"
echo "1. Faça SSH para a Instância Dev (IP Público: ${INSTANCE_A_PUBLIC_IP})."
echo "2. Do terminal da Instância Dev, tente pingar a Instância Data usando seu IP privado: ping -c 3 ${INSTANCE_B_PRIVATE_IP}"
echo "3. Do terminal da Instância Dev, tente SSH para a Instância Data usando seu IP privado: ssh ec2-user@${INSTANCE_B_PRIVATE_IP}"
echo "Ambos devem funcionar, confirmando a conectividade via VPC Peering."

# --- Comandos de Limpeza ---

# Para terminar as instâncias
# aws ec2 terminate-instances --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID}
# aws ec2 wait instance-terminated --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID}

# Para deletar as rotas de peering das tabelas de rotas
# aws ec2 delete-route --route-table-id ${VPC_A_RT_ID} --destination-cidr-block ${VPC_B_CIDR}
# aws ec2 delete-route --route-table-id ${VPC_B_RT_ID} --destination-cidr-block ${VPC_A_CIDR}

# Para deletar a conexão de peering
# aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id ${PEERING_CONNECTION_ID}

# Para deletar os Security Groups
# aws ec2 delete-security-group --group-id ${VPC_A_SG_ID}
# aws ec2 delete-security-group --group-id ${VPC_B_SG_ID}

# Para deletar os Internet Gateways
# aws ec2 detach-internet-gateway --vpc-id ${VPC_A_ID} --internet-gateway-id ${VPC_A_IGW_ID}
# aws ec2 delete-internet-gateway --internet-gateway-id ${VPC_A_IGW_ID}
# aws ec2 detach-internet-gateway --vpc-id ${VPC_B_ID} --internet-gateway-id ${VPC_B_IGW_ID}
# aws ec2 delete-internet-gateway --internet-gateway-id ${VPC_B_IGW_ID}

# Para deletar as sub-redes
# aws ec2 delete-subnet --subnet-id ${VPC_A_SUBNET_ID}
# aws ec2 delete-subnet --subnet-id ${VPC_B_SUBNET_ID}

# Para deletar as tabelas de rotas (se não forem as principais e não tiverem associações)
# aws ec2 delete-route-table --route-table-id ${VPC_A_RT_ID}
# aws ec2 delete-route-table --route-table-id ${VPC_B_RT_ID}

# Para deletar as VPCs
# aws ec2 delete-vpc --vpc-id ${VPC_A_ID}
# aws ec2 delete-vpc --vpc-id ${VPC_B_ID}