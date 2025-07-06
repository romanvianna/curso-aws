#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar uma Site-to-Site VPN ---

# Cenário: Este script demonstra a criação dos componentes da AWS para uma VPN
# Site-to-Site. Ele cria um Virtual Private Gateway (VGW), um Customer Gateway (CGW)
# e a conexão VPN. A configuração do lado on-premises (simulada aqui por outra VPC)
# é um processo manual que envolve a instalação e configuração de um software VPN.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# VPC A (Nuvem - Produção)
VPC_A_NAME="VPC-Cloud-VPN"
VPC_A_CIDR="10.10.0.0/16"
VPC_A_SUBNET_CIDR="10.10.1.0/24"
VPC_A_AZ="us-east-1a"

# VPC B (Simula On-Premises - Escritório Remoto)
VPC_B_NAME="VPC-OnPrem-VPN"
VPC_B_CIDR="192.168.0.0/16"
VPC_B_SUBNET_CIDR="192.168.1.0/24"
VPC_B_AZ="us-east-1a"

# Key Pair para as instâncias (substitua pelo seu)
KEY_PAIR_NAME="my-ec2-key"
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
MY_LOCAL_IP="203.0.113.10/32" # Substitua pelo seu IP público

# ASN para o Customer Gateway (deve ser privado, 64512-65534)
ON_PREM_ASN="65002"

echo "INFO: Iniciando a configuração da Site-to-Site VPN..."

# --- Funções Auxiliares para Criar VPCs e Instâncias ---
create_vpc_and_instance() {
  local vpc_name=$1
  local vpc_cidr=$2
  local subnet_cidr=$3
  local az=$4
  local instance_name=$5
  local associate_public_ip=$6
  local sg_ingress_cidr=$7

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

  if [ "$associate_public_ip" = "true" ]; then
    aws ec2 modify-subnet-attribute --subnet-id ${SUBNET_ID} --map-public-ip-on-launch
  fi

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
  # Permite tráfego VPN (UDP 500 e 4500) para o Customer Gateway simulado
  if [ "$instance_name" = "On-Prem-Router" ]; then
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol udp --port 500 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id ${SG_ID} --protocol udp --port 4500 --cidr 0.0.0.0/0
  fi

  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ${AMI_ID} \
    --count 1 \
    --instance-type t2.micro \
    --key-name ${KEY_PAIR_NAME} \
    --subnet-id ${SUBNET_ID} \
    --security-group-ids ${SG_ID} \
    $(if [ "$associate_public_ip" = "true" ]; then echo "--associate-public-ip-address"; else echo "--no-associate-public-ip-address"; fi) \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${instance_name}}]" \
    --query 'Instances[0].InstanceId' \
    --output text)
  aws ec2 wait instance-running --instance-ids ${INSTANCE_ID}
  INSTANCE_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
  INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

  echo "SUCCESS: ${vpc_name} e ${instance_name} criadas."
  echo "${VPC_ID} ${SUBNET_ID} ${RT_ID} ${SG_ID} ${INSTANCE_ID} ${INSTANCE_PRIVATE_IP} ${INSTANCE_PUBLIC_IP}"
}

# --- 1. Configurar a VPC "Nuvem" (VPC-A) ---
read -r VPC_A_DETAILS <<< $(create_vpc_and_instance "${VPC_A_NAME}" "${VPC_A_CIDR}" "${VPC_A_SUBNET_CIDR}" "${VPC_A_AZ}" "Cloud-Server" "true" "${VPC_B_CIDR}")
read -r VPC_A_ID VPC_A_SUBNET_ID VPC_A_RT_ID VPC_A_SG_ID INSTANCE_A_ID INSTANCE_A_PRIVATE_IP INSTANCE_A_PUBLIC_IP <<< "${VPC_A_DETAILS}"

echo "INFO: Criando Virtual Private Gateway (VGW) para VPC A..."
VGW_ID=$(aws ec2 create-vpn-gateway \
  --type ipsec.1 \
  --tag-specifications 'ResourceType=vpn-gateway,Tags=[{Key=Name,Value=Lab-VGW}]' \
  --query 'VpnGateway.VpnGatewayId' \
  --output text)
aws ec2 attach-vpn-gateway --vpn-gateway-id ${VGW_ID} --vpc-id ${VPC_A_ID}

echo "SUCCESS: VGW criado e anexado: ${VGW_ID}"

# Habilitar propagação de rota na tabela de rotas da VPC A
aws ec2 enable-vpc-classic-link-dns-support --vpc-id ${VPC_A_ID} # Workaround para enable-vpc-route-propagation
aws ec2 create-route-table-propagation --route-table-id ${VPC_A_RT_ID} --vpn-gateway-id ${VGW_ID}
echo "INFO: Propagação de rota habilitada para VGW na VPC A."

# --- 2. Configurar a VPC "On-Premises" (VPC-B) e o "Customer Gateway" ---
read -r VPC_B_DETAILS <<< $(create_vpc_and_instance "${VPC_B_NAME}" "${VPC_B_CIDR}" "${VPC_B_SUBNET_CIDR}" "${VPC_B_AZ}" "On-Prem-Router" "true" "${VPC_A_CIDR}")
read -r VPC_B_ID VPC_B_SUBNET_ID VPC_B_RT_ID VPC_B_SG_ID INSTANCE_B_ID INSTANCE_B_PRIVATE_IP INSTANCE_B_PUBLIC_IP <<< "${VPC_B_DETAILS}"

# --- 3. Criar os Componentes da VPN na AWS ---
echo "INFO: Criando Customer Gateway (CGW)..."
CGW_ID=$(aws ec2 create-customer-gateway \
  --type ipsec.1 \
  --public-ip ${INSTANCE_B_PUBLIC_IP} \
  --bgp-asn ${ON_PREM_ASN} \
  --tag-specifications 'ResourceType=customer-gateway,Tags=[{Key=Name,Value=On-Prem-CGW}]' \
  --query 'CustomerGateway.CustomerGatewayId' \
  --output text)

echo "SUCCESS: CGW criado: ${CGW_ID}"

echo "INFO: Criando Conexão Site-to-Site VPN..."
VPN_CONNECTION_ID=$(aws ec2 create-vpn-connection \
  --type ipsec.1 \
  --customer-gateway-id ${CGW_ID} \
  --vpn-gateway-id ${VGW_ID} \
  --options "{\"StaticRoutesOnly\":false}" \
  --tag-specifications 'ResourceType=vpn-connection,Tags=[{Key=Name,Value=AWS-to-On-Prem-VPN}]' \
  --query 'VpnConnection.VpnConnectionId' \
  --output text)

echo "SUCCESS: Conexão VPN criada: ${VPN_CONNECTION_ID}. Aguardando túneis ficarem UP..."

# --- 4. Configurar o Lado On-Premises e Validar (Passos Manuais/Simulados) ---
echo "\n--- Próximos Passos (Configuração On-Premises e Validação) ---"
echo "1. Baixe o arquivo de configuração da VPN no console da AWS para a conexão ${VPN_CONNECTION_ID}."
echo "2. Configure o software VPN (ex: strongSwan) na sua instância On-Prem-Router (${INSTANCE_B_PUBLIC_IP}) usando este arquivo."
echo "3. Inicie o serviço VPN na instância On-Prem-Router."
echo "4. Monitore o status dos túneis VPN no console da AWS (VPN Connections -> Tunnel Details). Eles devem ficar UP."
echo "5. Atualize os Security Groups das instâncias para permitir ICMP e SSH entre ${VPC_A_CIDR} e ${VPC_B_CIDR}."

# Exemplo de atualização de SG para permitir comunicação entre as VPCs via VPN
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
  --group-id ${VPC_B_SG_ID} \
  --protocol icmp \
  --port -1 \
  --cidr ${VPC_A_CIDR}
aws ec2 authorize-security-group-ingress \
  --group-id ${VPC_B_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${VPC_A_CIDR}

echo "Security Groups atualizados para permitir comunicação entre as VPCs."

echo "\n6. Após os túneis estarem UP, faça SSH para a instância Cloud-Server (${INSTANCE_A_PUBLIC_IP})."
echo "7. Do terminal da Cloud-Server, tente pingar a instância On-Prem-Router usando seu IP privado: ping -c 3 ${INSTANCE_B_PRIVATE_IP}"
echo "8. Tente SSH para a instância On-Prem-Router: ssh ec2-user@${INSTANCE_B_PRIVATE_IP}"
echo "Ambos devem funcionar, confirmando a conectividade via VPN."

# --- Comandos de Limpeza ---

# Para terminar as instâncias
# aws ec2 terminate-instances --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID}
# aws ec2 wait instance-terminated --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID}

# Para deletar a conexão VPN
# aws ec2 delete-vpn-connection --vpn-connection-id ${VPN_CONNECTION_ID}

# Para deletar o Customer Gateway
# aws ec2 delete-customer-gateway --customer-gateway-id ${CGW_ID}

# Para desanexar o VGW da VPC
# aws ec2 detach-vpn-gateway --vpn-gateway-id ${VGW_ID} --vpc-id ${VPC_A_ID}

# Para deletar o VGW
# aws ec2 delete-vpn-gateway --vpn-gateway-id ${VGW_ID}

# Para deletar os Security Groups
# aws ec2 delete-security-group --group-id ${VPC_A_SG_ID}
# aws ec2 delete-security-group --group-id ${VPC_B_SG_ID}

# Para deletar os Internet Gateways
# aws ec2 detach-internet-gateway --vpc-id ${VPC_A_ID} --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_A_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)
# aws ec2 delete-internet-gateway --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_A_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)
# aws ec2 detach-internet-gateway --vpc-id ${VPC_B_ID} --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_B_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)
# aws ec2 delete-internet-gateway --internet-gateway-id $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=${VPC_B_ID} --query 'InternetGateways[0].InternetGatewayId' --output text)

# Para deletar as sub-redes
# aws ec2 delete-subnet --subnet-id ${VPC_A_SUBNET_ID}
# aws ec2 delete-subnet --subnet-id ${VPC_B_SUBNET_ID}

# Para deletar as tabelas de rotas (se não forem as principais e não tiverem associações)
# aws ec2 delete-route-table --route-table-id ${VPC_A_RT_ID}
# aws ec2 delete-route-table --route-table-id ${VPC_B_RT_ID}

# Para deletar as VPCs
# aws ec2 delete-vpc --vpc-id ${VPC_A_ID}
# aws ec2 delete-vpc --vpc-id ${VPC_B_ID}