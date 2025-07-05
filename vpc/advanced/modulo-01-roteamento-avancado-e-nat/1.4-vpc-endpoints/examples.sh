#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Criar um VPC Endpoint de Gateway para S3 e um VPC Endpoint de Interface para EC2 API.

# Pré-requisitos:
# 1. Uma VPC existente (substitua <VPC_ID>).
# 2. Uma tabela de rotas privada existente (substitua <ROUTE_TABLE_ID_PRIVADO>).
# 3. Sub-redes privadas existentes em pelo menos duas AZs (substitua <SUBNET_ID_PRIVADO_AZ1> e <SUBNET_ID_PRIVADO_AZ2>).
# 4. Um Security Group para o Interface Endpoint (substitua <SECURITY_GROUP_ID_PARA_ENDPOINT>).

# Variáveis de exemplo (substitua pelos seus IDs reais)
# VPC_ID="vpc-0abcdef1234567890"
# ROUTE_TABLE_ID_PRIVADO="rtb-0abcdef1234567890"
# SUBNET_ID_PRIVADO_AZ1="subnet-0abcdef1234567890"
# SUBNET_ID_PRIVADO_AZ2="subnet-0abcdef1234567891"
# SECURITY_GROUP_ID_PARA_ENDPOINT="sg-0abcdef1234567890"

echo "--- Criando VPC Endpoint de Gateway para S3 ---"
S3_ENDPOINT_ID=$(aws ec2 create-vpc-endpoint \
  --vpc-id ${VPC_ID} \
  --service-name com.amazonaws.us-east-1.s3 \
  --vpc-endpoint-type Gateway \
  --route-table-ids ${ROUTE_TABLE_ID_PRIVADO} \
  --query 'VpcEndpoint.VpcEndpointId' \
  --output text)

echo "VPC Endpoint de Gateway para S3 criado: $S3_ENDPOINT_ID"

echo "--- Criando VPC Endpoint de Interface para EC2 API ---"
EC2_ENDPOINT_ID=$(aws ec2 create-vpc-endpoint \
  --vpc-id ${VPC_ID} \
  --service-name com.amazonaws.us-east-1.ec2 \
  --vpc-endpoint-type Interface \
  --subnet-ids ${SUBNET_ID_PRIVADO_AZ1} ${SUBNET_ID_PRIVADO_AZ2} \
  --security-group-ids ${SECURITY_GROUP_ID_PARA_ENDPOINT} \
  --private-dns-enabled \
  --query 'VpcEndpoint.VpcEndpointId' \
  --output text)

echo "VPC Endpoint de Interface para EC2 API criado: $EC2_ENDPOINT_ID"

# --- Comandos Adicionais ---

# Descrever VPC Endpoints
aws ec2 describe-vpc-endpoints

# Descrever as rotas de uma tabela de rotas (para verificar o Gateway Endpoint)
# aws ec2 describe-route-tables --route-table-ids ${ROUTE_TABLE_ID_PRIVADO}

# Deletar um VPC Endpoint
# aws ec2 delete-vpc-endpoints --vpc-endpoint-ids <VPC_ENDPOINT_ID>