#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar Transit Gateway (TGW) ---

# Cenário: Este script demonstra como criar um Transit Gateway e conectar
# três VPCs a ele, permitindo a comunicação entre elas de forma escalável.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# VPC A (Dev)
VPC_A_NAME="VPC-Dev-TGW"
VPC_A_CIDR="10.10.0.0/16"
VPC_A_SUBNET_CIDR="10.10.1.0/24"
VPC_A_AZ="us-east-1a"

# VPC B (Test)
VPC_B_NAME="VPC-Test-TGW"
VPC_B_CIDR="10.20.0.0/16"
VPC_B_SUBNET_CIDR="10.20.1.0/24"
VPC_B_AZ="us-east-1a"

# VPC C (Prod)
VPC_C_NAME="VPC-Prod-TGW"
VPC_C_CIDR="10.30.0.0/16"
VPC_C_SUBNET_CIDR="10.30.1.0/24"
VPC_C_AZ="us-east-1a"

# Key Pair para as instâncias (substitua pelo seu)
KEY_PAIR_NAME="my-ec2-key"
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
MY_LOCAL_IP="203.0.113.10/32" # Substitua pelo seu IP público

echo "INFO: Iniciando a configuração do Transit Gateway..."

# --- Funções Auxiliares para Criar VPCs e Instâncias ---
create_vpc_and_instance() {
  local vpc_name=$1
  local vpc_cidr=$2
  local subnet_cidr=$3
  local az=$4
  local instance_name=$5

  echo "INFO: Criando VPC ${vpc_name}..."
  VPC_ID=$(aws ec2 create-vpc \
    --cidr-block ${vpc_cidr} \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${vpc_name}}]" \
    --query 'Vpc.VpcId' \
    --output text)

  SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id ${VPC_ID} \
    --cidr-block ${subnet_cidr} \
    --availability-zone ${az} \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${vpc_name}-Subnet}]" \
    --query 'Subnet.SubnetId' \
    --output text)

  aws ec2 modify-subnet-attribute --subnet-id ${SUBNET_ID} --map-public-ip-on-launch

  IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${vpc_name}-IGW}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)
  aws ec2 attach-internet-gateway --vpc-id ${VPC_ID} --internet-gateway-id ${IGW_ID}

  RT_ID=$(aws ec2 create-route-table \
    --vpc-id ${VPC_ID} \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${vpc_name}-RT}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)
  aws ec2 create-route --route-table-id ${RT_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${IGW_ID} > /dev/null
  aws ec2 associate-route-table --subnet-id ${SUBNET_ID} --route-table-id ${RT_ID} > /dev/null

  SG_ID=$(aws ec2 create-security-group \
    --group-name ${vpc_name}-SG \
    --description "SG for ${vpc_name}" \
    --vpc-id ${VPC_ID} \
    --query 'GroupId' \
    --output text)
  aws ec2 authorize-security-group-ingress \
    --group-id ${SG_ID} \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_LOCAL_IP}

  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ${AMI_ID} \
    --count 1 \
    --instance-type t2.micro \
    --key-name ${KEY_PAIR_NAME} \
    --subnet-id ${SUBNET_ID} \
    --security-group-ids ${SG_ID} \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${instance_name}}]" \
    --query 'Instances[0].InstanceId' \
    --output text)
  aws ec2 wait instance-running --instance-ids ${INSTANCE_ID}
  INSTANCE_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

  echo "SUCCESS: ${vpc_name} e ${instance_name} criadas."
  echo "${VPC_ID} ${SUBNET_ID} ${RT_ID} ${SG_ID} ${INSTANCE_ID} ${INSTANCE_PRIVATE_IP}"
}

# --- 1. Criar as Três VPCs e Instâncias ---
read -r VPC_A_DETAILS <<< $(create_vpc_and_instance "${VPC_A_NAME}" "${VPC_A_CIDR}" "${VPC_A_SUBNET_CIDR}" "${VPC_A_AZ}" "Instance-Dev")
read -r VPC_A_ID VPC_A_SUBNET_ID VPC_A_RT_ID VPC_A_SG_ID INSTANCE_A_ID INSTANCE_A_PRIVATE_IP <<< "${VPC_A_DETAILS}"

read -r VPC_B_DETAILS <<< $(create_vpc_and_instance "${VPC_B_NAME}" "${VPC_B_CIDR}" "${VPC_B_SUBNET_CIDR}" "${VPC_B_AZ}" "Instance-Test")
read -r VPC_B_ID VPC_B_SUBNET_ID VPC_B_RT_ID VPC_B_SG_ID INSTANCE_B_ID INSTANCE_B_PRIVATE_IP <<< "${VPC_B_DETAILS}"

read -r VPC_C_DETAILS <<< $(create_vpc_and_instance "${VPC_C_NAME}" "${VPC_C_CIDR}" "${VPC_C_SUBNET_CIDR}" "${VPC_C_AZ}" "Instance-Prod")
read -r VPC_C_ID VPC_C_SUBNET_ID VPC_C_RT_ID VPC_C_SG_ID INSTANCE_C_ID INSTANCE_C_PRIVATE_IP <<< "${VPC_C_DETAILS}"

# --- 2. Criar o Transit Gateway ---
echo "INFO: Criando Transit Gateway..."
TGW_ID=$(aws ec2 create-transit-gateway \
  --description "Lab Transit Gateway" \
  --tag-specifications "ResourceType=transit-gateway,Tags=[{Key=Name,Value=Lab-TGW}]" \
  --query 'TransitGateway.TransitGatewayId' \
  --output text)

echo "SUCCESS: Transit Gateway criado: ${TGW_ID}. Aguardando ficar disponível..."
aws ec2 wait transit-gateway-available --transit-gateway-ids ${TGW_ID}

# --- 3. Anexar as VPCs ao TGW ---
echo "INFO: Anexando VPCs ao TGW..."

ATTACH_A_ID=$(aws ec2 create-transit-gateway-vpc-attachment \
  --transit-gateway-id ${TGW_ID} \
  --vpc-id ${VPC_A_ID} \
  --subnet-ids ${VPC_A_SUBNET_ID} \
  --tag-specifications "ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=TGW-Attach-VPC-Dev}]" \
  --query 'TransitGatewayVpcAttachment.TransitGatewayAttachmentId' \
  --output text)
aws ec2 wait transit-gateway-attachment-available --transit-gateway-attachment-ids ${ATTACH_A_ID}
echo "VPC-Dev anexada: ${ATTACH_A_ID}"

ATTACH_B_ID=$(aws ec2 create-transit-gateway-vpc-attachment \
  --transit-gateway-id ${TGW_ID} \
  --vpc-id ${VPC_B_ID} \
  --subnet-ids ${VPC_B_SUBNET_ID} \
  --tag-specifications "ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=TGW-Attach-VPC-Test}]" \
  --query 'TransitGatewayVpcAttachment.TransitGatewayAttachmentId' \
  --output text)
aws ec2 wait transit-gateway-attachment-available --transit-gateway-attachment-ids ${ATTACH_B_ID}
echo "VPC-Test anexada: ${ATTACH_B_ID}"

ATTACH_C_ID=$(aws ec2 create-transit-gateway-vpc-attachment \
  --transit-gateway-id ${TGW_ID} \
  --vpc-id ${VPC_C_ID} \
  --subnet-ids ${VPC_C_SUBNET_ID} \
  --tag-specifications "ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=TGW-Attach-VPC-Prod}]" \
  --query 'TransitGatewayVpcAttachment.TransitGatewayAttachmentId' \
  --output text)
aws ec2 wait transit-gateway-attachment-available --transit-gateway-attachment-ids ${ATTACH_C_ID}
echo "VPC-Prod anexada: ${ATTACH_C_ID}"

# --- 4. Atualizar as Tabelas de Rotas das VPCs para apontar para o TGW ---
echo "INFO: Atualizando tabelas de rotas das VPCs..."

# Rota na VPC A para VPC B e C via TGW
aws ec2 create-transit-gateway-route \
  --transit-gateway-route-table-id $(aws ec2 describe-transit-gateways --transit-gateway-ids ${TGW_ID} --query 'TransitGateways[0].Options.AssociationDefaultRouteTableId' --output text) \
  --destination-cidr-block ${VPC_B_CIDR} \
  --transit-gateway-attachment-id ${ATTACH_B_ID} > /dev/null
aws ec2 create-transit-gateway-route \
  --transit-gateway-route-table-id $(aws ec2 describe-transit-gateways --transit-gateway-ids ${TGW_ID} --query 'TransitGateways[0].Options.AssociationDefaultRouteTableId' --output text) \
  --destination-cidr-block ${VPC_C_CIDR} \
  --transit-gateway-attachment-id ${ATTACH_C_ID} > /dev/null

# Adicionar rotas nas tabelas de rotas das VPCs para o TGW
aws ec2 create-route --route-table-id ${VPC_A_RT_ID} --destination-cidr-block ${VPC_B_CIDR} --transit-gateway-id ${TGW_ID} > /dev/null
aws ec2 create-route --route-table-id ${VPC_A_RT_ID} --destination-cidr-block ${VPC_C_CIDR} --transit-gateway-id ${TGW_ID} > /dev/null
echo "Rotas adicionadas na VPC A."

aws ec2 create-route --route-table-id ${VPC_B_RT_ID} --destination-cidr-block ${VPC_A_CIDR} --transit-gateway-id ${TGW_ID} > /dev/null
aws ec2 create-route --route-table-id ${VPC_B_RT_ID} --destination-cidr-block ${VPC_C_CIDR} --transit-gateway-id ${TGW_ID} > /dev/null
echo "Rotas adicionadas na VPC B."

aws ec2 create-route --route-table-id ${VPC_C_RT_ID} --destination-cidr-block ${VPC_A_CIDR} --transit-gateway-id ${TGW_ID} > /dev/null
aws ec2 create-route --route-table-id ${VPC_C_RT_ID} --destination-cidr-block ${VPC_B_CIDR} --transit-gateway-id ${TGW_ID} > /dev/null
echo "Rotas adicionadas na VPC C."

# --- 5. Atualizar Security Groups para permitir comunicação via TGW ---
echo "INFO: Atualizando Security Groups..."

# Permite ICMP (ping) e SSH entre as VPCs
# SG da VPC A
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
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_A_SG_ID} \
  --protocol icmp \
  --port -1 \
  --cidr ${VPC_C_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_A_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${VPC_C_CIDR}

# SG da VPC B
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
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_B_SG_ID} \
  --protocol icmp \
  --port -1 \
  --cidr ${VPC_C_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_B_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${VPC_C_CIDR}

# SG da VPC C
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_C_SG_ID} \
  --protocol icmp \
  --port -1 \
  --cidr ${VPC_A_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_C_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${VPC_A_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_C_SG_ID} \
  --protocol icmp \
  --port -1 \
  --cidr ${VPC_B_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_C_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${VPC_B_CIDR}

echo "Security Groups atualizados."

echo "-------------------------------------"
echo "Configuração de Transit Gateway concluída!"
echo "TGW ID: ${TGW_ID}"
echo "VPC-Dev IP Privado: ${INSTANCE_A_PRIVATE_IP}"
echo "VPC-Test IP Privado: ${INSTANCE_B_PRIVATE_IP}"
echo "VPC-Prod IP Privado: ${INSTANCE_C_PRIVATE_IP}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação) ---"
echo "1. Faça SSH para a Instância Dev (ou Test, ou Prod) usando seu IP público."
echo "2. Do terminal da instância, tente pingar as instâncias nas outras VPCs usando seus IPs privados."
echo "   Ex: ping -c 3 ${INSTANCE_B_PRIVATE_IP}"
echo "   Ex: ssh ec2-user@${INSTANCE_C_PRIVATE_IP}"
echo "Todos os pings e SSHs entre as VPCs devem funcionar."

# --- Comandos de Limpeza ---

# Para terminar as instâncias
# aws ec2 terminate-instances --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID} ${INSTANCE_C_ID}
# aws ec2 wait instance-terminated --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID} ${INSTANCE_C_ID}

# Para deletar as rotas do TGW nas tabelas de rotas das VPCs
# aws ec2 delete-route --route-table-id ${VPC_A_RT_ID} --destination-cidr-block ${VPC_B_CIDR}
# aws ec2 delete-route --route-table-id ${VPC_A_RT_ID} --destination-cidr-block ${VPC_C_CIDR}
# aws ec2 delete-route --route-table-id ${VPC_B_RT_ID} --destination-cidr-block ${VPC_A_CIDR}
# aws ec2 delete-route --route-table-id ${VPC_B_RT_ID} --destination-cidr-block ${VPC_C_CIDR}
# aws ec2 delete-route --route-table-id ${VPC_C_RT_ID} --destination-cidr-block ${VPC_A_CIDR}
# aws ec2 delete-route --route-table-id ${VPC_C_RT_ID} --destination-cidr-block ${VPC_B_CIDR}

# Para deletar os anexos do TGW
# aws ec2 delete-transit-gateway-vpc-attachment --transit-gateway-attachment-id ${ATTACH_A_ID}
# aws ec2 delete-transit-gateway-vpc-attachment --transit-gateway-attachment-id ${ATTACH_B_ID}
# aws ec2 delete-transit-gateway-vpc-attachment --transit-gateway-attachment-id ${ATTACH_C_ID}
# aws ec2 wait transit-gateway-attachment-deleted --transit-gateway-attachment-ids ${ATTACH_A_ID} ${ATTACH_B_ID} ${ATTACH_C_ID}

# Para deletar o Transit Gateway
# aws ec2 delete-transit-gateway --transit-gateway-id ${TGW_ID}
# aws ec2 wait transit-gateway-deleted --transit-gateway-ids ${TGW_ID}

# Para deletar os Security Groups
# aws ec2 delete-security-group --group-id ${VPC_A_SG_ID}
# aws ec2 delete-security-group --group-id ${VPC_B_SG_ID}
# aws ec2 delete-security-group --group-id ${VPC_C_SG_ID}

# Para deletar os Internet Gateways
# aws ec2 detach-internet-gateway --vpc-id ${VPC_A_ID} --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_A_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)
# aws ec2 delete-internet-gateway --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_A_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)
# aws ec2 detach-internet-gateway --vpc-id ${VPC_B_ID} --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_B_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)
# aws ec2 delete-internet-gateway --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_B_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)
# aws ec2 detach-internet-gateway --vpc-id ${VPC_C_ID} --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_C_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)
# aws ec2 delete-internet-gateway --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_C_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)

# Para deletar as sub-redes
# aws ec2 delete-subnet --subnet-id ${VPC_A_SUBNET_ID}
# aws ec2 delete-subnet --subnet-id ${VPC_B_SUBNET_ID}
# aws ec2 delete-subnet --subnet-id ${VPC_C_SUBNET_ID}

# Para deletar as tabelas de rotas (se não forem as principais e não tiverem associações)
# aws ec2 delete-route-table --route-table-id ${VPC_A_RT_ID}
# aws ec2 delete-route-table --route-table-id ${VPC_B_RT_ID}
# aws ec2 delete-route-table --route-table-id ${VPC_C_RT_ID}

# Para deletar as VPCs
# aws ec2 delete-vpc --vpc-id ${VPC_A_ID}
# aws ec2 delete-vpc --vpc-id ${VPC_B_ID}
# aws ec2 delete-vpc --vpc-id ${VPC_C_ID}