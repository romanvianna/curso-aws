#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar AWS Backup e simular DR ---

# Cenário: Este script demonstra como configurar o AWS Backup para proteger volumes EBS
# e replicá-los para uma região de DR. Ele também simula a criação de infraestrutura
# para uma estratégia Pilot Light.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Região Primária
export DR_REGION="us-east-2" # Região de DR

# Substitua pelo ID de um volume EBS existente para backup
# EBS_VOLUME_ID="vol-0abcdef1234567890"

echo "INFO: Iniciando a configuração de DR com AWS Backup..."

# --- Parte 1: Configurar o AWS Backup (Backup e Restore) ---

# 1. Criar um Cofre de Backup (Backup Vault) na região primária
echo "INFO: Criando Backup Vault na região ${AWS_REGION}..."
BACKUP_VAULT_NAME="critical-data-vault-$(date +%s)"
BACKUP_VAULT_ARN=$(aws backup create-backup-vault \
  --backup-vault-name ${BACKUP_VAULT_NAME} \
  --query 'BackupVaultArn' \
  --output text)

echo "SUCCESS: Backup Vault criado: ${BACKUP_VAULT_ARN}"

# 2. Criar um Plano de Backup
echo "INFO: Criando Plano de Backup..."
BACKUP_PLAN_NAME="EC2-Daily-Plan-$(date +%s)"
BACKUP_PLAN_ID=$(aws backup create-backup-plan \
  --backup-plan '{"BackupPlanName":"'${BACKUP_PLAN_NAME}'","Rules":[{"RuleName":"Daily-EBS-Backup","TargetBackupVaultName":"'${BACKUP_VAULT_NAME}'","ScheduleExpression":"cron(0 12 * * ? *)","Lifecycle":{"DeleteAfterDays":35},"CopyActions":[{"DestinationBackupVaultArn":"arn:aws:backup:${DR_REGION}:$(aws sts get-caller-identity --query Account --output text):backup-vault:${BACKUP_VAULT_NAME}","Lifecycle":{"DeleteAfterDays":35}}]}]}' \
  --query 'BackupPlanId' \
  --output text)

echo "SUCCESS: Plano de Backup criado: ${BACKUP_PLAN_ID}"

# 3. Atribuir Recursos ao Plano (Exemplo: um volume EBS específico)
echo "INFO: Atribuindo recursos ao Plano de Backup..."
# Nota: Para este exemplo, você precisaria de um EBS_VOLUME_ID existente.
# aws backup put-backup-selection \
#   --backup-plan-id ${BACKUP_PLAN_ID} \
#   --backup-selection '{"SelectionName":"EC2-Volumes","IamRoleArn":"arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/service-role/AWSBackupDefaultServiceRole","Resources":[{"ResourceArn":"arn:aws:ec2:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):volume/${EBS_VOLUME_ID}"}]}'

echo "SUCCESS: Recursos atribuídos ao Plano de Backup (verifique o console para detalhes)."

# --- Parte 2: Simular uma Estratégia Pilot Light (Criação de Infraestrutura Básica na Região de DR) ---
echo "INFO: Simulando infraestrutura Pilot Light na região ${DR_REGION}..."

# 1. Criar VPC na Região de DR
DR_VPC_ID=$(aws ec2 create-vpc \
  --region ${DR_REGION} \
  --cidr-block 10.254.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=DR-PilotLight-VPC}]' \
  --query 'Vpc.VpcId' \
  --output text)

echo "SUCCESS: DR VPC criada em ${DR_REGION}: ${DR_VPC_ID}"

# 2. Criar Sub-rede Pública na Região de DR
DR_PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --region ${DR_REGION} \
  --vpc-id ${DR_VPC_ID} \
  --cidr-block 10.254.1.0/24 \
  --availability-zone ${DR_REGION}a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=DR-Public-Subnet}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "SUCCESS: DR Public Subnet criada: ${DR_PUBLIC_SUBNET_ID}"

# 3. Criar Internet Gateway na Região de DR
DR_IGW_ID=$(aws ec2 create-internet-gateway \
  --region ${DR_REGION} \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=DR-IGW}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
aws ec2 attach-internet-gateway \
  --region ${DR_REGION} \
  --vpc-id ${DR_VPC_ID} \
  --internet-gateway-id ${DR_IGW_ID}

echo "SUCCESS: DR IGW criado e anexado: ${DR_IGW_ID}"

# 4. Criar Tabela de Rotas Pública na Região de DR
DR_PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --region ${DR_REGION} \
  --vpc-id ${DR_VPC_ID} \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=DR-Public-RT}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --region ${DR_REGION} \
  --route-table-id ${DR_PUBLIC_RT_ID} \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id ${DR_IGW_ID} > /dev/null

aws ec2 associate-route-table \
  --region ${DR_REGION} \
  --subnet-id ${DR_PUBLIC_SUBNET_ID} \
  --route-table-id ${DR_PUBLIC_RT_ID} > /dev/null

echo "SUCCESS: DR Public Route Table criada e associada: ${DR_PUBLIC_RT_ID}"

echo "-------------------------------------"
echo "Configuração de DR simulada concluída!"
echo "Backup Vault: ${BACKUP_VAULT_NAME}"
echo "DR VPC ID: ${DR_VPC_ID} em ${DR_REGION}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação e Limpeza) ---"
echo "1. Verifique o console do AWS Backup para o plano e os backups."
echo "2. Verifique o console da VPC na região ${DR_REGION} para a infraestrutura criada."
echo "3. Para simular um failover, você precisaria restaurar um backup na região de DR e lançar instâncias."

# --- Comandos de Limpeza ---

# Para deletar a infraestrutura de DR na região ${DR_REGION}
# aws ec2 delete-subnet --subnet-id ${DR_PUBLIC_SUBNET_ID} --region ${DR_REGION}
# aws ec2 detach-internet-gateway --internet-gateway-id ${DR_IGW_ID} --vpc-id ${DR_VPC_ID} --region ${DR_REGION}
# aws ec2 delete-internet-gateway --internet-gateway-id ${DR_IGW_ID} --region ${DR_REGION}
# aws ec2 delete-route-table --route-table-id ${DR_PUBLIC_RT_ID} --region ${DR_REGION}
# aws ec2 delete-vpc --vpc-id ${DR_VPC_ID} --region ${DR_REGION}

# Para deletar o Plano de Backup
# aws backup delete-backup-plan --backup-plan-id ${BACKUP_PLAN_ID}

# Para deletar o Cofre de Backup (deve estar vazio)
# aws backup delete-backup-vault --backup-vault-name ${BACKUP_VAULT_NAME}