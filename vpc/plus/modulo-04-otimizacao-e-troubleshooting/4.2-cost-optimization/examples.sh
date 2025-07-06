#!/bin/bash

# --- Exemplo de comandos AWS CLI para otimização de custos de rede ---

# Cenário: Este script demonstra como usar a AWS CLI para simular a análise de custos
# de transferência de dados e como um VPC Gateway Endpoint para S3 pode reduzir custos.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Substitua pelos IDs da sua VPC e tabela de rotas privada
VPC_ID="vpc-0abcdef1234567890" # Exemplo
PRIVATE_ROUTE_TABLE_ID="rtb-0abcdef1234567891" # Exemplo

echo "INFO: Iniciando a simulação de otimização de custos de rede..."

# --- Parte 1: Simulação de Análise de Custos (Conceitual) ---
echo "INFO: Para uma análise real de custos, use o AWS Cost Explorer no console."
echo "INFO: Filtre por 'Service: EC2' e 'Usage Type Group: EC2: Data Transfer - Regional' e 'EC2: NAT Gateway - Processing'."
echo "INFO: Isso ajudará a identificar os maiores geradores de custo de rede."

# Exemplo de comando para descrever o uso de NAT Gateways (para identificar tráfego)
# aws ec2 describe-nat-gateways --query 'NatGateways[*].{ID:NatGatewayId,State:State,PublicIp:NatGatewayAddresses[0].PublicIp}' --output table

# Exemplo de comando para obter métricas de uso do NAT Gateway (requer CloudWatch)
# aws cloudwatch get-metric-statistics \
#   --namespace AWS/NATGateway \
#   --metric-name BytesOutAndIn \
#   --dimensions Name=NatGatewayId,Value=<YOUR_NAT_GATEWAY_ID> \
#   --start-time $(date -d '1 month ago' +%Y-%m-%dT%H:%M:%SZ) \
#   --end-time $(date +%Y-%m-%dT%H:%M:%SZ) \
#   --period 86400 \
#   --statistic Sum \
#   --query 'Datapoints[*].{Timestamp:Timestamp,Sum:Sum}' \
#   --output table

echo "\n--- Parte 2: Simulação de Otimização de Custos com VPC Gateway Endpoint para S3 ---"
echo "Cenário: Reduzir custos de tráfego para S3 que passa por um NAT Gateway."

# --- Pré-requisito: Um NAT Gateway existente na sua VPC ---
# Para este exemplo, assumimos que você já tem um NAT Gateway configurado
# e que o tráfego da sua sub-rede privada para o S3 passa por ele.

# --- 1. Criar um VPC Gateway Endpoint para S3 ---
echo "INFO: Criando VPC Gateway Endpoint para S3..."
S3_ENDPOINT_ID=$(aws ec2 create-vpc-endpoint \
  --vpc-id ${VPC_ID} \
  --service-name com.amazonaws.${AWS_REGION}.s3 \
  --vpc-endpoint-type Gateway \
  --route-table-ids ${PRIVATE_ROUTE_TABLE_ID} \
  --query 'VpcEndpoint.VpcEndpointId' \
  --output text)

echo "SUCCESS: VPC Gateway Endpoint para S3 criado: ${S3_ENDPOINT_ID}"

echo "\nINFO: O tráfego da sua sub-rede privada para o S3 agora passará pelo Gateway Endpoint (gratuito),\nINFO: contornando o NAT Gateway e eliminando os custos de processamento de dados do NAT Gateway para este tráfego.\nINFO: Verifique a tabela de rotas (${PRIVATE_ROUTE_TABLE_ID}) para ver a nova rota para o S3.\n"

# --- Comandos de Limpeza ---

# Para deletar o VPC Gateway Endpoint para S3
# aws ec2 delete-vpc-endpoints --vpc-endpoint-ids ${S3_ENDPOINT_ID}