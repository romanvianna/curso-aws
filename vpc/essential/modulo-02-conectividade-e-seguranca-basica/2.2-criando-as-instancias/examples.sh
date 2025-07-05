#!/bin/bash

# --- Exemplo de comandos AWS CLI para lançar instâncias EC2 em sub-redes públicas e privadas ---

# Cenário: Este script demonstra como provisionar instâncias EC2 em diferentes tipos de sub-redes
# (pública e privada) e configurar seus Security Groups para controlar o acesso.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Substitua pelos IDs da sua VPC, sub-redes e Security Groups
# Estes IDs devem ser obtidos de um provisionamento anterior (ex: Módulo 1.3 ou 2.1)
VPC_ID="vpc-0abcdef1234567890" # Exemplo
PUBLIC_SUBNET_ID="subnet-0abcdef1234567891" # Exemplo
PRIVATE_SUBNET_ID="subnet-0abcdef1234567892" # Exemplo
WEB_SERVER_SG_ID="sg-0abcdef1234567893" # Exemplo: SG para o servidor web (HTTP/HTTPS/SSH)
DB_SERVER_SG_ID="sg-0abcdef1234567894" # Exemplo: SG para o servidor DB (MySQL/SSH)
KEY_PAIR_NAME="my-ec2-key" # Substitua pelo nome do seu Key Pair
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)

echo "INFO: Iniciando o lançamento das instâncias EC2..."

# --- 1. Lançar Instância na Sub-rede Pública (WebServer) ---
echo "INFO: Lançando WebServer-Lab na sub-rede pública..."
WEB_SERVER_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${PUBLIC_SUBNET_ID} \
  --security-group-ids ${WEB_SERVER_SG_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=WebServer-Lab}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "WebServer-Lab lançado com ID: $WEB_SERVER_INSTANCE_ID. Aguardando ficar em estado 'running'..."

aws ec2 wait instance-running --instance-ids ${WEB_SERVER_INSTANCE_ID}

WEB_SERVER_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids ${WEB_SERVER_INSTANCE_ID} \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "WebServer-Lab está rodando. IP Público: $WEB_SERVER_PUBLIC_IP"

# --- 2. Lançar Instância na Sub-rede Privada (DBServer) ---
echo "INFO: Lançando DBServer-Lab na sub-rede privada..."
DB_SERVER_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${PRIVATE_SUBNET_ID} \
  --security-group-ids ${DB_SERVER_SG_ID} \
  --no-associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DBServer-Lab}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "DBServer-Lab lançado com ID: $DB_SERVER_INSTANCE_ID. Aguardando ficar em estado 'running'..."

aws ec2 wait instance-running --instance-ids ${DB_SERVER_INSTANCE_ID}

DB_SERVER_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids ${DB_SERVER_INSTANCE_ID} \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "DBServer-Lab está rodando. IP Privado: $DB_SERVER_PRIVATE_IP"

echo "-------------------------------------"
echo "Lançamento de instâncias concluído!"
echo "WebServer-Lab ID: ${WEB_SERVER_INSTANCE_ID}, IP Público: ${WEB_SERVER_PUBLIC_IP}"
echo "DBServer-Lab ID: ${DB_SERVER_INSTANCE_ID}, IP Privado: ${DB_SERVER_PRIVATE_IP}"
echo "-------------------------------------"

echo "\n--- Próximos Passos (Validação) ---"
echo "1. Tente fazer SSH para o WebServer-Lab usando o IP Público: ssh -i ${KEY_PAIR_NAME}.pem ec2-user@${WEB_SERVER_PUBLIC_IP}"
echo "2. Do WebServer-Lab, tente pingar ou usar netcat para o DBServer-Lab usando o IP Privado: ping ${DB_SERVER_PRIVATE_IP}"
echo "3. Observe que o DBServer-Lab não tem IP Público e não pode ser acessado diretamente da internet."

# --- Comandos de Limpeza ---

# Para terminar as instâncias
# aws ec2 terminate-instances --instance-ids ${WEB_SERVER_INSTANCE_ID} ${DB_SERVER_INSTANCE_ID}

# Aguardar a terminação
# aws ec2 wait instance-terminated --instance-ids ${WEB_SERVER_INSTANCE_ID} ${DB_SERVER_INSTANCE_ID}