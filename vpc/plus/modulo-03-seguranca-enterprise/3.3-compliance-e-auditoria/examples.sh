#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar AWS Config para Conformidade e Auditoria ---

# Cenário: Este script demonstra como habilitar o AWS Config, adicionar uma regra gerenciada
# para detectar Security Groups não conformes (SSH aberto para 0.0.0.0/0) e configurar
# a remediação automática para remover a regra ofensiva.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Substitua pelo ID de um Security Group existente para teste, ou crie um novo.
# TEST_SG_ID="sg-0abcdef1234567890"

echo "INFO: Iniciando a configuração do AWS Config..."

# --- 1. Configurar o AWS Config ---
echo "INFO: Habilitando AWS Config..."

# Criar um bucket S3 para o Config (se não existir)
CONFIG_BUCKET_NAME="aws-config-bucket-$(aws sts get-caller-identity --query Account --output text)-${AWS_REGION}"
aws s3api create-bucket --bucket ${CONFIG_BUCKET_NAME} --region ${AWS_REGION} > /dev/null

# Criar a IAM Role para o AWS Config
CONFIG_ROLE_NAME="aws-service-role-config"
TRUST_POLICY_JSON='''{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'''

CONFIG_ROLE_ARN=$(aws iam create-role \
  --role-name ${CONFIG_ROLE_NAME} \
  --assume-role-policy-document "$TRUST_POLICY_JSON" \
  --query 'Role.Arn' \
  --output text 2>/dev/null || aws iam get-role --role-name ${CONFIG_ROLE_NAME} --query 'Role.Arn' --output text)

# Anexar a política gerenciada ao role
aws iam attach-role-policy \
  --role-name ${CONFIG_ROLE_NAME} \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWS_ConfigRole

echo "SUCCESS: IAM Role para Config criada/verificada: ${CONFIG_ROLE_ARN}"

# Iniciar o gravador de configuração
aws configservice put-configuration-recorder \
  --configuration-recorder Name=default,RoleARN=${CONFIG_ROLE_ARN}

# Configurar o canal de entrega
DELIVERY_CHANNEL_NAME="default"
aws configservice put-delivery-channel \
  --delivery-channel name=${DELIVERY_CHANNEL_NAME},s3BucketName=${CONFIG_BUCKET_NAME}

aws configservice start-configuration-recorder --configuration-recorder-name default

echo "SUCCESS: AWS Config habilitado e gravador iniciado."

# --- 2. Adicionar a Regra de Detecção (restricted-ssh) ---
echo "INFO: Adicionando regra gerenciada 'restricted-ssh'..."
aws configservice put-config-rule \
  --config-rule Name=restricted-ssh,SourceIdentifier=RESTRICTED_SSH,SourceOwner=AWS,Scope={"ComplianceResourceTypes":["AWS::EC2::SecurityGroup"]}

echo "SUCCESS: Regra 'restricted-ssh' adicionada. Aguarde alguns minutos para a avaliação inicial."

# --- 3. Violar a Política Intencionalmente (Criar um SG não conforme) ---
echo "INFO: Criando Security Group não conforme para teste..."
TEST_SG_ID=$(aws ec2 create-security-group \
  --group-name Non-Compliant-SG-$(date +%s) \
  --description "Test SG for Config compliance" \
  --vpc-id $(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text) \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id ${TEST_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "SUCCESS: Security Group não conforme criado: ${TEST_SG_ID}"

echo "-------------------------------------"
echo "Configuração do AWS Config e simulação de não conformidade concluídas!"
echo "Security Group de Teste ID: ${TEST_SG_ID}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação e Remediação) ---"
echo "1. Aguarde 5-10 minutos para o AWS Config detectar a não conformidade."
echo "2. Navegue até o console do AWS Config -> Rules. A regra 'restricted-ssh' deve mostrar 1 recurso não conforme."
echo "3. Para configurar a remediação automática, vá no console do Config, selecione a regra 'restricted-ssh', clique em Actions -> Manage remediation."
echo "   - Selecione Automatic remediation."
echo "   - Escolha a ação 'AWS-DisablePublicAccessForSecurityGroup'."
echo "   - Configure os parâmetros: IpProtocol=tcp, FromPort=22, ToPort=22, CidrIp=0.0.0.0/0."
echo "   - Salve. O Config pode pedir para criar uma role de remediação. Autorize."
echo "4. Para testar a remediação, adicione novamente a regra SSH 0.0.0.0/0 ao ${TEST_SG_ID}. O Config deve removê-la automaticamente."

# --- Comandos de Limpeza ---

# Para deletar o Security Group de teste
# aws ec2 delete-security-group --group-id ${TEST_SG_ID}

# Para parar o gravador de configuração
# aws configservice stop-configuration-recorder --configuration-recorder-name default

# Para deletar o canal de entrega
# aws configservice delete-delivery-channel --delivery-channel-name default

# Para deletar o gravador de configuração
# aws configservice delete-configuration-recorder --configuration-recorder-name default

# Para deletar a regra do Config
# aws configservice delete-config-rule --config-rule-name restricted-ssh

# Para deletar o bucket S3 do Config (deve estar vazio)
# aws s3 rb s3://${CONFIG_BUCKET_NAME} --force

# Para deletar a IAM Role do Config (se criada por este script)
# aws iam detach-role-policy --role-name ${CONFIG_ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/service-role/AWS_ConfigRole
# aws iam delete-role --role-name ${CONFIG_ROLE_NAME}