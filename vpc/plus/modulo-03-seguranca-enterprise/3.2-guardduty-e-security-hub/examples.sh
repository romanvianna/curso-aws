#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar GuardDuty e Security Hub ---

# Cenário: Este script demonstra como habilitar o Amazon GuardDuty e o AWS Security Hub,
# e como simular um finding de segurança para observar a detecção.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS
KEY_PAIR_NAME="my-ec2-key" # Substitua pelo nome do seu Key Pair
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
SUBNET_ID="subnet-0abcdef1234567890" # Substitua pelo ID de uma sub-rede pública existente
SG_ID="sg-0abcdef1234567891" # Substitua pelo ID de um Security Group que permita SSH do seu IP

echo "INFO: Iniciando a configuração de GuardDuty e Security Hub..."

# --- 1. Habilitar o Amazon GuardDuty ---
echo "INFO: Habilitando Amazon GuardDuty..."
aws guardduty enable-organization-admin-account --admin-account-id $(aws sts get-caller-identity --query Account --output text) 2>/dev/null || true # Se estiver em uma organização
aws guardduty create-detector --enable --query 'DetectorId' --output text > /dev/null

echo "SUCCESS: Amazon GuardDuty habilitado."

# --- 2. Habilitar o AWS Security Hub ---
echo "INFO: Habilitando AWS Security Hub..."
aws securityhub enable-security-hub > /dev/null

echo "SUCCESS: AWS Security Hub habilitado."

# --- 3. Gerar um Resultado de Segurança (Simulação) ---
echo "INFO: Lançando instância de teste para gerar um finding de segurança..."
TEST_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${SUBNET_ID} \
  --security-group-ids ${SG_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=GuardDuty-Test-Instance}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "SUCCESS: Instância de teste lançada: ${TEST_INSTANCE_ID}. Aguardando ficar em estado 'running'..."
aws ec2 wait instance-running --instance-ids ${TEST_INSTANCE_ID}
TEST_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${TEST_INSTANCE_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Instância de teste IP Público: ${TEST_INSTANCE_PUBLIC_IP}"

echo "INFO: Conectando à instância e executando comando para gerar finding..."
# Este comando simula uma atividade de mineração de criptomoedas que o GuardDuty detecta.
# Requer que a instância tenha acesso à internet para resolver o DNS.
ssh -o StrictHostKeyChecking=no -i ${KEY_PAIR_NAME}.pem ec2-user@${TEST_INSTANCE_PUBLIC_IP} "dig pool.minergate.com"

echo "SUCCESS: Comando executado na instância. Aguarde alguns minutos para o GuardDuty gerar o finding."

echo "-------------------------------------"
echo "Configuração e simulação concluídas!"
echo "Instância de Teste ID: ${TEST_INSTANCE_ID}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação) ---"
echo "1. Aguarde 5-15 minutos."
echo "2. Navegue até o console do Amazon GuardDuty -> Findings. Procure por um finding como 'CryptoCurrency:EC2/BitcoinTool.B!DNS'."
echo "3. Navegue até o console do AWS Security Hub -> Findings. O mesmo finding do GuardDuty deve aparecer aqui, normalizado."

# --- Comandos de Limpeza ---

# Para terminar a instância de teste
# aws ec2 terminate-instances --instance-ids ${TEST_INSTANCE_ID}
# aws ec2 wait instance-terminated --instance-ids ${TEST_INSTANCE_ID}

# Para desabilitar o GuardDuty
# aws guardduty disassociate-members --detector-id <DETECTOR_ID> --account-ids <ACCOUNT_ID> # Se for multi-conta
# aws guardduty delete-detector --detector-id <DETECTOR_ID>
# (Obtenha o DETECTOR_ID com: aws guardduty list-detectors)

# Para desabilitar o Security Hub
# aws securityhub disable-security-hub