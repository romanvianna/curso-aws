#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar uma VPC de Serviços Compartilhados (Shared Services VPC) ---

# Cenário: Este script demonstra como configurar uma arquitetura de VPC de Serviços Compartilhados
# usando AWS Organizations e AWS Resource Access Manager (RAM). Ele cria duas contas (simuladas),
# uma VPC de serviços e compartilha uma sub-rede com a conta de aplicação.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Contas de exemplo (substitua pelos seus e-mails de teste)
# A conta que executa este script é a conta de gerenciamento da Organization.
NETWORK_ACCOUNT_EMAIL="network.account+test@example.com" # E-mail para a conta de rede
NETWORK_ACCOUNT_NAME="Network-Account-$(date +%s)"
APP_ACCOUNT_EMAIL="app.account+test@example.com" # E-mail para a conta de aplicação
APP_ACCOUNT_NAME="App-Account-$(date +%s)"

SHARED_VPC_CIDR="10.0.0.0/16"
SHARED_SUBNET_CIDR="10.0.1.0/24"
SHARED_SUBNET_AZ="us-east-1a"

echo "INFO: Iniciando a configuração da VPC de Serviços Compartilhados..."

# --- Pré-requisito: Criar Organização (se ainda não existir) ---
ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text 2>/dev/null || true)

if [ -z "$ORG_ID" ]; then
  echo "INFO: Criando nova organização..."
  ORG_ID=$(aws organizations create-organization --feature-set ALL --query 'Organization.Id' --output text)
  echo "SUCCESS: Organização criada com ID: ${ORG_ID}"
  echo "INFO: Aguardando a organização ser totalmente provisionada..."
  sleep 30
else
  echo "INFO: Organização já existe com ID: ${ORG_ID}"
fi

ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
echo "Root OU ID: ${ROOT_ID}"

# --- 1. Criar Contas de Rede e Aplicação (Simuladas) ---
echo "INFO: Criando Network Account..."
CREATE_NETWORK_ACCOUNT_REQUEST_ID=$(aws organizations create-account \
  --email ${NETWORK_ACCOUNT_EMAIL} \
  --account-name ${NETWORK_ACCOUNT_NAME} \
  --query 'CreateAccountStatus.Id' \
  --output text)
NETWORK_ACCOUNT_ID=$(aws organizations describe-create-account-status \
  --create-account-request-id ${CREATE_NETWORK_ACCOUNT_REQUEST_ID} \
  --query 'CreateAccountStatus.AccountId' \
  --output text)
while [ -z "$NETWORK_ACCOUNT_ID" ]; do
  echo "INFO: Aguardando Network Account ser criada..."
  sleep 10
  NETWORK_ACCOUNT_ID=$(aws organizations describe-create-account-status \
    --create-account-request-id ${CREATE_NETWORK_ACCOUNT_REQUEST_ID} \
    --query 'CreateAccountStatus.AccountId' \
    --output text)
done
echo "SUCCESS: Network Account ID: ${NETWORK_ACCOUNT_ID}"

echo "INFO: Criando App Account..."
CREATE_APP_ACCOUNT_REQUEST_ID=$(aws organizations create-account \
  --email ${APP_ACCOUNT_EMAIL} \
  --account-name ${APP_ACCOUNT_NAME} \
  --query 'CreateAccountStatus.Id' \
  --output text)
APP_ACCOUNT_ID=$(aws organizations describe-create-account-status \
  --create-account-request-id ${CREATE_APP_ACCOUNT_REQUEST_ID} \
  --query 'CreateAccountStatus.AccountId' \
  --output text)
while [ -z "$APP_ACCOUNT_ID" ]; do
  echo "INFO: Aguardando App Account ser criada..."
  sleep 10
  APP_ACCOUNT_ID=$(aws organizations describe-create-account-status \
    --create-account-request-id ${CREATE_APP_ACCOUNT_REQUEST_ID} \
    --query 'CreateAccountStatus.AccountId' \
    --output text)
done
echo "SUCCESS: App Account ID: ${APP_ACCOUNT_ID}"

# --- 2. Criar a Shared Services VPC na Network Account ---
echo "INFO: Criando Shared Services VPC na Network Account..."
# AssumeRole para a Network Account para criar a VPC
NETWORK_ACCOUNT_ROLE_ARN="arn:aws:iam::${NETWORK_ACCOUNT_ID}:role/OrganizationAccountAccessRole"
CREDENTIALS=$(aws sts assume-role --role-arn ${NETWORK_ACCOUNT_ROLE_ARN} --role-session-name NetworkAccountSession --query 'Credentials' --output json)
export AWS_ACCESS_KEY_ID=$(echo ${CREDENTIALS} | jq -r '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo ${CREDENTIALS} | jq -r '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo ${CREDENTIALS} | jq -r '.SessionToken')

SHARED_VPC_ID=$(aws ec2 create-vpc \
  --cidr-block ${SHARED_VPC_CIDR} \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=Shared-Services-VPC}]" \
  --query 'Vpc.VpcId' \
  --output text)

SHARED_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${SHARED_VPC_ID} \
  --cidr-block ${SHARED_SUBNET_CIDR} \
  --availability-zone ${SHARED_SUBNET_AZ} \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=Shared-Subnet-A}]" \
  --query 'Subnet.SubnetId' \
  --output text)

echo "SUCCESS: Shared Services VPC (${SHARED_VPC_ID}) e Subnet (${SHARED_SUBNET_ID}) criadas na Network Account."

# --- 3. Habilitar o Compartilhamento no AWS Organizations (na conta de gerenciamento) ---
echo "INFO: Habilitando compartilhamento com AWS Organizations no RAM..."
# Voltar para as credenciais da conta de gerenciamento
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws ram enable-sharing-with-aws-organization
echo "SUCCESS: Compartilhamento com AWS Organizations habilitado."

# --- 4. Criar o Compartilhamento de Recursos (na Network Account) ---
echo "INFO: Criando compartilhamento de recursos na Network Account..."
# AssumeRole para a Network Account novamente
CREDENTIALS=$(aws sts assume-role --role-arn ${NETWORK_ACCOUNT_ROLE_ARN} --role-session-name NetworkAccountSession --query 'Credentials' --output json)
export AWS_ACCESS_KEY_ID=$(echo ${CREDENTIALS} | jq -r '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo ${CREDENTIALS} | jq -r '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo ${CREDENTIALS} | jq -r '.SessionToken')

RESOURCE_SHARE_ARN=$(aws ram create-resource-share \
  --name VPC-Subnet-Share \
  --resource-arns arn:aws:ec2:${AWS_REGION}:${NETWORK_ACCOUNT_ID}:subnet/${SHARED_SUBNET_ID} \
  --principals ${APP_ACCOUNT_ID} \
  --query 'resourceShare.resourceShareArn' \
  --output text)
echo "SUCCESS: Compartilhamento de recursos criado: ${RESOURCE_SHARE_ARN}"

# --- 5. Lançar Instância na Sub-rede Compartilhada (na App Account) ---
echo "INFO: Lançando instância na sub-rede compartilhada na App Account..."
# AssumeRole para a App Account
APP_ACCOUNT_ROLE_ARN="arn:aws:iam::${APP_ACCOUNT_ID}:role/OrganizationAccountAccessRole"
CREDENTIALS=$(aws sts assume-role --role-arn ${APP_ACCOUNT_ROLE_ARN} --role-session-name AppAccountSession --query 'Credentials' --output json)
export AWS_ACCESS_KEY_ID=$(echo ${CREDENTIALS} | jq -r '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo ${CREDENTIALS} | jq -r '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo ${CREDENTIALS} | jq -r '.SessionToken')

# Criar um Security Group na VPC compartilhada (mas gerenciado pela App Account)
APP_INSTANCE_SG_ID=$(aws ec2 create-security-group \
  --group-name App-Instance-SG \
  --description "SG for App Instance in Shared VPC" \
  --vpc-id ${SHARED_VPC_ID} \
  --query 'GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id ${APP_INSTANCE_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

APP_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --count 1 \
  --instance-type t2.micro \
  --key-name my-ec2-key \
  --subnet-id ${SHARED_SUBNET_ID} \
  --security-group-ids ${APP_INSTANCE_SG_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=App-Instance-Shared-VPC}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "SUCCESS: Instância (${APP_INSTANCE_ID}) lançada na sub-rede compartilhada."

# --- Limpeza de credenciais temporárias ---
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

echo "-------------------------------------"
echo "Configuração da VPC de Serviços Compartilhados concluída!"
echo "Network Account ID: ${NETWORK_ACCOUNT_ID}"
echo "App Account ID: ${APP_ACCOUNT_ID}"
echo "Shared VPC ID: ${SHARED_VPC_ID}"
echo "Shared Subnet ID: ${SHARED_SUBNET_ID}"
echo "Instância na Sub-rede Compartilhada ID: ${APP_INSTANCE_ID}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação) ---"
echo "1. Faça login na Network Account (${NETWORK_ACCOUNT_ID}) e verifique que a instância (${APP_INSTANCE_ID}) aparece na VPC Shared-Services-VPC."
echo "2. Faça login na App Account (${APP_ACCOUNT_ID}) e verifique que a sub-rede (${SHARED_SUBNET_ID}) aparece em VPC -> Subnets."
echo "3. Tente SSH para a instância App-Instance-Shared-VPC e verifique seu IP privado (deve ser do CIDR da Shared-Subnet-A)."

# --- Comandos de Limpeza ---

# Para terminar a instância na App Account
# aws ec2 terminate-instances --instance-ids ${APP_INSTANCE_ID} --profile <profile_app_account>

# Para deletar o Security Group na App Account
# aws ec2 delete-security-group --group-id ${APP_INSTANCE_SG_ID} --profile <profile_app_account>

# Para deletar o compartilhamento de recursos na Network Account
# aws ram delete-resource-share --resource-share-arn ${RESOURCE_SHARE_ARN} --profile <profile_network_account>

# Para deletar a Shared Services VPC e sub-rede na Network Account
# aws ec2 delete-subnet --subnet-id ${SHARED_SUBNET_ID} --profile <profile_network_account>
# aws ec2 delete-vpc --vpc-id ${SHARED_VPC_ID} --profile <profile_network_account>

# Para fechar as contas (requer login em cada conta e seguir o processo de fechamento)
# aws organizations close-account --account-id ${NETWORK_ACCOUNT_ID}
# aws organizations close-account --account-id ${APP_ACCOUNT_ID}