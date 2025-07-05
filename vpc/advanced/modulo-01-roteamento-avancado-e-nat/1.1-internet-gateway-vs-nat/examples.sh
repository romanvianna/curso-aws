#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Criar um NAT Gateway para uma sub-rede privada existente.

# Pré-requisitos:
# 1. Uma VPC com uma sub-rede pública e uma privada.
# 2. O ID da sub-rede pública onde o NAT Gateway será criado.

# Passo 1: Alocar um Elastic IP para o NAT Gateway
EIP_ALLOCATION_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
echo "Elastic IP alocado com ID: $EIP_ALLOCATION_ID"

# Passo 2: Criar o NAT Gateway na sub-rede pública
NAT_GATEWAY_ID=$(aws ec2 create-nat-gateway --subnet-id <SEU_SUBNET_ID_PUBLICO> --allocation-id $EIP_ALLOCATION_ID --query 'NatGateway.NatGatewayId' --output text)
echo "NAT Gateway criado com ID: $NAT_GATEWAY_ID. Aguardando ficar disponível..."

# Aguardar até que o NAT Gateway esteja disponível
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GATEWAY_ID

echo "NAT Gateway está disponível."

# Passo 3: Adicionar uma rota na tabela de rotas da sub-rede PRIVADA para o NAT Gateway
aws ec2 create-route --route-table-id <SEU_ROUTE_TABLE_ID_PRIVADO> --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GATEWAY_ID

echo "Rota para o NAT Gateway adicionada com sucesso."

# --- Comandos Adicionais ---

# Descrever NAT Gateways
aws ec2 describe-nat-gateways

# Deletar um NAT Gateway
# aws ec2 delete-nat-gateway --nat-gateway-id <NAT_GATEWAY_ID>

# Liberar um Elastic IP
# aws ec2 release-address --allocation-id <EIP_ALLOCATION_ID>