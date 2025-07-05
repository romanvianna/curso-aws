#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Habilitar VPC Flow Logs para uma VPC e AWS CloudTrail para a conta.

# Pré-requisitos:
# 1. Uma VPC existente (substitua <VPC_ID>).
# 2. Um bucket S3 para armazenar os logs (substitua <S3_BUCKET_NAME>).
# 3. Uma IAM Role para o Flow Logs (será criada aqui).

# Variáveis de exemplo (substitua pelos seus IDs/Nomes reais)
# VPC_ID="vpc-0abcdef1234567890"
# S3_BUCKET_NAME="my-flow-logs-bucket-unique-12345" # Deve ser globalmente único
# CLOUDWATCH_LOG_GROUP_NAME="/aws/cloudtrail/my-trail"

echo "--- Criando IAM Role para VPC Flow Logs ---"

FLOW_LOG_ROLE_NAME="VPCFlowLogRole"

# Cria a Trust Policy para a Role
TRUST_POLICY_JSON='''{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'''

FLOW_LOG_ROLE_ARN=$(aws iam create-role \
  --role-name ${FLOW_LOG_ROLE_NAME} \
  --assume-role-policy-document "$TRUST_POLICY_JSON" \
  --query 'Role.Arn' \
  --output text)

echo "IAM Role para Flow Logs criada: $FLOW_LOG_ROLE_ARN"

# Cria a Policy para a Role
FLOW_LOG_POLICY_JSON='''{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "s3:PutObject"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:s3:::'$S3_BUCKET_NAME'/*"
        }
    ]
}
'''

aws iam put-role-policy \
  --role-name ${FLOW_LOG_ROLE_NAME} \
  --policy-name VPCFlowLogPolicy \
  --policy-document "$FLOW_LOG_POLICY_JSON"

echo "Policy anexada à Role para Flow Logs."

echo "--- Habilitando VPC Flow Logs para a VPC ---"

# Formato de log customizado para incluir mais detalhes
LOG_FORMAT='version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status vpc-id subnet-id instance-id tcp-flags type pkt-srcaddr pkt-dstaddr'

FLOW_LOG_ID=$(aws ec2 create-flow-logs \
  --resource-ids ${VPC_ID} \
  --resource-type VPC \
  --traffic-type ALL \
  --log-destination-type s3 \
  --log-destination arn:aws:s3:::${S3_BUCKET_NAME} \
  --log-format "${LOG_FORMAT}" \
  --deliver-logs-permission-arn ${FLOW_LOG_ROLE_ARN} \
  --query 'FlowLogs[0].FlowLogId' \
  --output text)

echo "VPC Flow Log habilitado com ID: $FLOW_LOG_ID"

echo "--- Habilitando AWS CloudTrail ---"

# Cria um bucket S3 para o CloudTrail (se ainda não existir)
aws s3api create-bucket --bucket ${S3_BUCKET_NAME}-cloudtrail --region us-east-1 # Ajuste a região se necessário

# Cria o CloudTrail
aws cloudtrail create-trail \
  --name my-organization-trail \
  --s3-bucket-name ${S3_BUCKET_NAME}-cloudtrail \
  --cloud-watch-logs-log-group-arn arn:aws:logs:us-east-1:<YOUR_ACCOUNT_ID>:log-group:${CLOUDWATCH_LOG_GROUP_NAME}:* \
  --cloud-watch-logs-role-arn arn:aws:iam::<YOUR_ACCOUNT_ID>:role/CloudTrail_CloudWatchLogs_Role # Substitua pelo ARN de uma role existente ou crie uma

aws cloudtrail start-logging --name my-organization-trail

echo "AWS CloudTrail habilitado."

# --- Comandos Adicionais ---

# Descrever Flow Logs
aws ec2 describe-flow-logs

# Descrever Trails do CloudTrail
aws cloudtrail describe-trails

# Deletar um Flow Log
# aws ec2 delete-flow-logs --flow-log-ids <FLOW_LOG_ID>

# Deletar um Trail do CloudTrail
# aws cloudtrail stop-logging --name <TRAIL_NAME>
# aws cloudtrail delete-trail --name <TRAIL_NAME>