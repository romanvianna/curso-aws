#!/bin/bash

# --- Exemplo de comandos AWS CLI para otimização de performance de rede ---

# Cenário: Este script demonstra como criar um Placement Group do tipo Cluster,
# lançar duas instâncias EC2 dentro dele e, em seguida, fornece instruções
# para usar iperf3 para medir a performance de rede entre elas.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Substitua pelos IDs da sua VPC, sub-rede e Key Pair
VPC_ID="vpc-0abcdef1234567890" # Exemplo
SUBNET_ID="subnet-0abcdef1234567891" # Exemplo: Sub-rede pública na mesma AZ
KEY_PAIR_NAME="my-ec2-key" # Substitua pelo nome do seu Key Pair
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
INSTANCE_TYPE="c5n.large" # Tipo de instância com boa performance de rede
MY_LOCAL_IP="203.0.113.10/32" # Substitua pelo seu IP público para SSH

echo "INFO: Iniciando a configuração para teste de performance de rede..."

# --- 1. Criar o Placement Group (Cluster) ---
echo "INFO: Criando Placement Group 'HPC-Cluster-PG'"
PLACEMENT_GROUP_NAME="HPC-Cluster-PG-$(date +%s)"
PLACEMENT_GROUP_ARN=$(aws ec2 create-placement-group \
  --group-name ${PLACEMENT_GROUP_NAME} \
  --strategy cluster \
  --tag-specifications 'ResourceType=placement-group,Tags=[{Key=Name,Value=${PLACEMENT_GROUP_NAME}}]' \
  --query 'PlacementGroup.GroupArn' \
  --output text)

echo "SUCCESS: Placement Group criado: ${PLACEMENT_GROUP_ARN}"

# --- 2. Criar Security Group para as Instâncias de Teste ---
echo "INFO: Criando Security Group para as instâncias de teste..."
PERF_TEST_SG_ID=$(aws ec2 create-security-group \
  --group-name Perf-Test-SG-$(date +%s) \
  --description "SG for network performance testing" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)

# Permite todo o tráfego de entrada do próprio SG (para comunicação entre as instâncias no PG)
aws ec2 authorize-security-group-ingress \
  --group-id ${PERF_TEST_SG_ID} \
  --protocol -1 \
  --source-group ${PERF_TEST_SG_ID}

# Permite SSH do seu IP local
aws ec2 authorize-security-group-ingress \
  --group-id ${PERF_TEST_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

echo "SUCCESS: Security Group criado: ${PERF_TEST_SG_ID}"

# --- 3. Lançar a Instância 1 (Servidor iperf) no Placement Group ---
echo "INFO: Lançando Net-Perf-Server..."
SERVER_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type ${INSTANCE_TYPE} \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${SUBNET_ID} \
  --security-group-ids ${PERF_TEST_SG_ID} \
  --placement GroupName=${PLACEMENT_GROUP_NAME} \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Net-Perf-Server}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "SUCCESS: Net-Perf-Server lançado com ID: ${SERVER_INSTANCE_ID}. Aguardando..."
aws ec2 wait instance-running --instance-ids ${SERVER_INSTANCE_ID}
SERVER_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${SERVER_INSTANCE_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
SERVER_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${SERVER_INSTANCE_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Net-Perf-Server IP Privado: ${SERVER_PRIVATE_IP}, IP Público: ${SERVER_PUBLIC_IP}"

# --- 4. Lançar a Instância 2 (Cliente iperf) no MESMO Placement Group ---
echo "INFO: Lançando Net-Perf-Client..."
CLIENT_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type ${INSTANCE_TYPE} \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${SUBNET_ID} \
  --security-group-ids ${PERF_TEST_SG_ID} \
  --placement GroupName=${PLACEMENT_GROUP_NAME} \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Net-Perf-Client}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "SUCCESS: Net-Perf-Client lançado com ID: ${CLIENT_INSTANCE_ID}. Aguardando..."
aws ec2 wait instance-running --instance-ids ${CLIENT_INSTANCE_ID}
CLIENT_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${CLIENT_INSTANCE_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
CLIENT_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${CLIENT_INSTANCE_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Net-Perf-Client IP Privado: ${CLIENT_PRIVATE_IP}, IP Público: ${CLIENT_PUBLIC_IP}"

echo "-------------------------------------"
echo "Configuração para teste de performance concluída!"
echo "Placement Group: ${PLACEMENT_GROUP_NAME}"
echo "Net-Perf-Server IP Privado: ${SERVER_PRIVATE_IP}"
echo "Net-Perf-Client IP Privado: ${CLIENT_PRIVATE_IP}"
echo "-------------------------------------"

echo "\n--- Próximos Passos (Executar Teste iperf3) ---"
echo "1. Faça SSH para ambas as instâncias (Net-Perf-Server e Net-Perf-Client) usando seus IPs públicos."
echo "   ssh -i ${KEY_PAIR_NAME}.pem ec2-user@${SERVER_PUBLIC_IP}"
echo "   ssh -i ${KEY_PAIR_NAME}.pem ec2-user@${CLIENT_PUBLIC_IP}"

echo "2. Em AMBAS as instâncias, instale iperf3: sudo yum install iperf3 -y"

echo "3. Na instância Net-Perf-Server, inicie o servidor iperf3: iperf3 -s"

echo "4. Na instância Net-Perf-Client, execute o teste iperf3 apontando para o IP PRIVADO do servidor: iperf3 -c ${SERVER_PRIVATE_IP}"

echo "Observe o throughput (Bitrate) alcançado. Para testar Jumbo Frames, configure MTU 9001 em ambas as instâncias e use: iperf3 -c ${SERVER_PRIVATE_IP} -M 9000"

# --- Comandos de Limpeza ---

# Para terminar as instâncias
# aws ec2 terminate-instances --instance-ids ${SERVER_INSTANCE_ID} ${CLIENT_INSTANCE_ID}
# aws ec2 wait instance-terminated --instance-ids ${SERVER_INSTANCE_ID} ${CLIENT_INSTANCE_ID}

# Para deletar o Security Group
# aws ec2 delete-security-group --group-id ${PERF_TEST_SG_ID}

# Para deletar o Placement Group
# aws ec2 delete-placement-group --group-name ${PLACEMENT_GROUP_NAME}