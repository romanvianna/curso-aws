#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar NAT Gateway e testar conectividade de saída ---

# Cenário: Este script demonstra como provisionar um NAT Gateway em uma sub-rede pública
# e configurar o roteamento para que uma instância em uma sub-rede privada possa acessar a internet.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Substitua pelos IDs da sua VPC, sub-redes e Key Pair
# Estes IDs devem ser obtidos de um provisionamento anterior (ex: Módulo 3.1)
VPC_ID="vpc-0abcdef1234567890" # Exemplo
PUBLIC_SUBNET_ID="subnet-0abcdef1234567891" # Exemplo: Sub-rede pública onde o NAT GW será criado
PRIVATE_SUBNET_ID="subnet-0abcdef1234567892" # Exemplo: Sub-rede privada que precisa de acesso à internet
PRIVATE_ROUTE_TABLE_ID="rtb-0abcdef1234567893" # Exemplo: Tabela de rotas da sub-rede privada
KEY_PAIR_NAME="my-ec2-key" # Substitua pelo nome do seu Key Pair
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
SSH_SG_ID="sg-0abcdef1234567894" # Exemplo: Security Group que permite SSH do seu IP

echo "INFO: Iniciando a configuração do NAT Gateway e teste de conectividade..."

# --- 1. Alocar um Elastic IP para o NAT Gateway ---
echo "INFO: Alocando Elastic IP para o NAT Gateway..."
EIP_ALLOCATION_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' \
  --output text)
EIP_PUBLIC_IP=$(aws ec2 describe-addresses \
  --allocation-ids ${EIP_ALLOCATION_ID} \
  --query 'Addresses[0].PublicIp' \
  --output text)

echo "SUCCESS: Elastic IP alocado: ${EIP_PUBLIC_IP} (Allocation ID: ${EIP_ALLOCATION_ID})"

# --- 2. Criar o NAT Gateway na sub-rede pública ---
echo "INFO: Criando NAT Gateway na sub-rede ${PUBLIC_SUBNET_ID}..."
NAT_GATEWAY_ID=$(aws ec2 create-nat-gateway \
  --subnet-id ${PUBLIC_SUBNET_ID} \
  --allocation-id ${EIP_ALLOCATION_ID} \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=Lab-NAT-GW}]' \
  --query 'NatGateway.NatGatewayId' \
  --output text)

echo "SUCCESS: NAT Gateway criado com ID: ${NAT_GATEWAY_ID}. Aguardando ficar disponível..."

aws ec2 wait nat-gateway-available --nat-gateway-ids ${NAT_GATEWAY_ID}

echo "INFO: NAT Gateway está disponível."

# --- 3. Configurar o Roteamento da Sub-rede Privada ---
echo "INFO: Adicionando rota padrão para o NAT Gateway na tabela de rotas ${PRIVATE_ROUTE_TABLE_ID}..."
aws ec2 create-route \
  --route-table-id ${PRIVATE_ROUTE_TABLE_ID} \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id ${NAT_GATEWAY_ID} > /dev/null

echo "SUCCESS: Rota para o NAT Gateway adicionada à tabela de rotas privada."

# --- 4. Lançar Instância na Sub-rede Privada (AppServer) ---
echo "INFO: Lançando AppServer-Private na sub-rede privada ${PRIVATE_SUBNET_ID}..."
APP_SERVER_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${PRIVATE_SUBNET_ID} \
  --security-group-ids ${SSH_SG_ID} \
  --no-associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=AppServer-Private}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "SUCCESS: AppServer-Private lançado com ID: ${APP_SERVER_INSTANCE_ID}. Aguardando ficar em estado 'running'..."

aws ec2 wait instance-running --instance-ids ${APP_SERVER_INSTANCE_ID}

APP_SERVER_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids ${APP_SERVER_INSTANCE_ID} \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "INFO: AppServer-Private está rodando. IP Privado: ${APP_SERVER_PRIVATE_IP}"

echo "-------------------------------------"
echo "Configuração do NAT Gateway e lançamento da instância concluídos!"
echo "NAT Gateway ID: ${NAT_GATEWAY_ID}"
echo "AppServer-Private ID: ${APP_SERVER_INSTANCE_ID}, IP Privado: ${APP_SERVER_PRIVATE_IP}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação da Conectividade de Saída) ---"
echo "1. Faça SSH para o AppServer-Private usando seu IP privado (você precisará de um Bastion Host ou Session Manager para isso):"
echo "   ssh -i ${KEY_PAIR_NAME}.pem ec2-user@${APP_SERVER_PRIVATE_IP}"

echo "2. Uma vez conectado ao AppServer-Private, execute os seguintes comandos para testar o acesso à internet:"
echo "   sudo yum update -y"
echo "   curl https://www.google.com"
echo "Ambos devem ser executados com sucesso, provando que a instância privada pode acessar a internet via NAT Gateway."

# --- Comandos de Limpeza ---

# Para terminar a instância AppServer-Private
# aws ec2 terminate-instances --instance-ids ${APP_SERVER_INSTANCE_ID}
# aws ec2 wait instance-terminated --instance-ids ${APP_SERVER_INSTANCE_ID}

# Para deletar a rota para o NAT Gateway na tabela de rotas privada
# aws ec2 delete-route --route-table-id ${PRIVATE_ROUTE_TABLE_ID} --destination-cidr-block 0.0.0.0/0

# Para deletar o NAT Gateway
# aws ec2 delete-nat-gateway --nat-gateway-id ${NAT_GATEWAY_ID}
# aws ec2 wait nat-gateway-deleted --nat-gateway-ids ${NAT_GATEWAY_ID}

# Para liberar o Elastic IP
# aws ec2 release-address --allocation-id ${EIP_ALLOCATION_ID}