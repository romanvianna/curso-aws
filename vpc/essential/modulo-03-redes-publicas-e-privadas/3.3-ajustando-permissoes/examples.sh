#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar IAM Roles para instâncias EC2 ---

# Cenário: Este script demonstra como criar uma IAM Role com permissões para acessar
# um bucket S3 e anexá-la a uma instância EC2. Em seguida, valida o acesso a partir da instância.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS
S3_BUCKET_NAME="my-lab-iam-role-test-bucket-$(date +%s)" # Nome único para o bucket
KEY_PAIR_NAME="my-ec2-key" # Substitua pelo nome do seu Key Pair
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
SUBNET_ID="subnet-0abcdef1234567890" # Substitua pelo ID de uma sub-rede existente
SG_ID="sg-0abcdef1234567891" # Substitua pelo ID de um Security Group que permita SSH

echo "INFO: Iniciando a configuração de IAM Role para EC2..."

# --- 1. Criar um Bucket S3 de Teste ---
echo "INFO: Criando bucket S3 de teste: ${S3_BUCKET_NAME}..."
aws s3 mb s3://${S3_BUCKET_NAME}
aws s3 cp /dev/null s3://${S3_BUCKET_NAME}/hello.txt # Cria um arquivo vazio para teste

echo "SUCCESS: Bucket S3 criado e arquivo de teste adicionado."

# --- 2. Criar a IAM Role (EC2-S3-ReadOnly-Role) ---
echo "INFO: Criando IAM Role EC2-S3-ReadOnly-Role..."

# Define a Trust Policy para a Role (permite que o serviço EC2 a assuma)
TRUST_POLICY_JSON='''{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'''

ROLE_ARN=$(aws iam create-role \
  --role-name EC2-S3-ReadOnly-Role \
  --assume-role-policy-document "$TRUST_POLICY_JSON" \
  --query 'Role.Arn' \
  --output text)

echo "SUCCESS: IAM Role criada com ARN: $ROLE_ARN"

# Anexa a política gerenciada AmazonS3ReadOnlyAccess à Role
aws iam attach-role-policy \
  --role-name EC2-S3-ReadOnly-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

echo "SUCCESS: Política AmazonS3ReadOnlyAccess anexada à Role."

# --- 3. Lançar Instância EC2 com a IAM Role Anexada ---
echo "INFO: Lançando instância EC2 com a IAM Role..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${SUBNET_ID} \
  --security-group-ids ${SG_ID} \
  --iam-instance-profile Name=EC2-S3-ReadOnly-Role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=IAM-Role-Test-Instance}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "SUCCESS: Instância EC2 lançada com ID: ${INSTANCE_ID}. Aguardando ficar em estado 'running'..."

aws ec2 wait instance-running --instance-ids ${INSTANCE_ID}

INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids ${INSTANCE_ID} \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "INFO: Instância está rodando. IP Público: ${INSTANCE_PUBLIC_IP}"

echo "-------------------------------------"
echo "Configuração concluída!"
echo "Instância ID: ${INSTANCE_ID}"
echo "IAM Role ARN: ${ROLE_ARN}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação) ---"
echo "1. Faça SSH para a instância EC2:"
echo "   ssh -i ${KEY_PAIR_NAME}.pem ec2-user@${INSTANCE_PUBLIC_IP}"

echo "2. Dentro da instância, execute o comando para listar o bucket S3:"
echo "   aws s3 ls s3://${S3_BUCKET_NAME}/"
echo "   Isso deve funcionar sem que você precise configurar credenciais na instância."
echo "3. Tente deletar o bucket (deve falhar):"
echo "   aws s3 rb s3://${S3_BUCKET_NAME}/"

# --- Comandos de Limpeza ---

# Para terminar a instância
# aws ec2 terminate-instances --instance-ids ${INSTANCE_ID}
# aws ec2 wait instance-terminated --instance-ids ${INSTANCE_ID}

# Para desanexar a política da role
# aws iam detach-role-policy --role-name EC2-S3-ReadOnly-Role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Para deletar a role
# aws iam delete-role --role-name EC2-S3-ReadOnly-Role

# Para deletar o bucket S3 (certifique-se de que está vazio primeiro)
# aws s3 rm s3://${S3_BUCKET_NAME} --recursive
# aws s3 rb s3://${S3_BUCKET_NAME}