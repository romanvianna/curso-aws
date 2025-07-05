#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Criar um Application Load Balancer (ALB) para expor uma aplicação web
# em sub-redes privadas de forma segura e escalável.

# Pré-requisitos:
# 1. Uma VPC com sub-redes públicas em pelo menos duas Zonas de Disponibilidade.
# 2. Instâncias EC2 em sub-redes privadas rodando a aplicação web (ex: Apache/Nginx).
# 3. Security Groups para o ALB e para as instâncias de aplicação.

# Variáveis de exemplo (substitua pelos seus IDs reais)
# SUBNET_ID_PUBLIC_1="subnet-0abcdef1234567890"
# SUBNET_ID_PUBLIC_2="subnet-0abcdef1234567891"
# SG_ALB_ID="sg-0abcdef1234567890"
# VPC_ID="vpc-0abcdef1234567890"
# INSTANCE_ID_APP_1="i-0abcdef1234567890"
# INSTANCE_ID_APP_2="i-0abcdef1234567891"

# Passo 1: Criar um Target Group
# Define para onde o ALB enviará o tráfego (instâncias de aplicação).
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
  --name my-web-app-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id ${VPC_ID} \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target Group criado: $TARGET_GROUP_ARN"

# Passo 2: Registrar instâncias no Target Group
# As instâncias EC2 que rodarão a aplicação.
aws elbv2 register-targets \
  --target-group-arn ${TARGET_GROUP_ARN} \
  --targets Id=${INSTANCE_ID_APP_1} Id=${INSTANCE_ID_APP_2}

echo "Instâncias registradas no Target Group."

# Passo 3: Criar o Application Load Balancer (ALB)
# O ALB será internet-facing e estará nas sub-redes públicas.
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name my-application-alb \
  --subnets ${SUBNET_ID_PUBLIC_1} ${SUBNET_ID_PUBLIC_2} \
  --security-groups ${SG_ALB_ID} \
  --scheme internet-facing \
  --type application \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

echo "ALB criado: $ALB_ARN. Aguardando ficar ativo..."

# Aguardar até que o ALB esteja ativo
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN

# Passo 4: Criar um Listener HTTP para o ALB
# O listener encaminha o tráfego da porta 80 para o Target Group.
aws elbv2 create-listener \
  --load-balancer-arn ${ALB_ARN} \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}

echo "Listener HTTP criado para o ALB."

# --- Comandos Adicionais ---

# Descrever Load Balancers
aws elbv2 describe-load-balancers

# Descrever Target Groups
aws elbv2 describe-target-groups

# Obter o DNS Name do ALB (para acesso via navegador)
# aws elbv2 describe-load-balancers --load-balancer-arns ${ALB_ARN} --query 'LoadBalancers[0].DNSName' --output text

# Deletar um Listener
# aws elbv2 delete-listener --listener-arn <LISTENER_ARN>

# Deletar um Target Group
# aws elbv2 delete-target-group --target-group-arn <TARGET_GROUP_ARN>

# Deletar um Load Balancer
# aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>