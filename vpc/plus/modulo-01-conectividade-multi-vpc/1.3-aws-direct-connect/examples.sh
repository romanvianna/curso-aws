#!/bin/bash

# --- Exemplo de comandos AWS CLI para simular a configuração do AWS Direct Connect (lado AWS) ---

# Cenário: Este script demonstra a criação dos componentes virtuais da AWS necessários
# para uma conexão Direct Connect, como Virtual Private Gateway e Direct Connect Gateway.
# A conexão física do Direct Connect e a Virtual Interface (VIF) são processos manuais
# ou com parceiros e não podem ser totalmente automatizados via CLI neste contexto.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS
VPC_ID="vpc-0abcdef1234567890" # Substitua pelo ID da sua VPC
ON_PREM_ASN="65000" # ASN (Autonomous System Number) da sua rede on-premises
DX_GW_ASN="65001" # ASN para o Direct Connect Gateway (deve ser privado, 64512-65534)

echo "INFO: Iniciando a simulação de configuração do AWS Direct Connect (lado AWS)..."

# --- 1. Criar o Virtual Private Gateway (VGW) ---
echo "INFO: Criando Virtual Private Gateway (VGW)..."
VGW_ID=$(aws ec2 create-vpn-gateway \
  --type ipsec.1 \
  --amazon-side-asn ${ON_PREM_ASN} \
  --tag-specifications 'ResourceType=vpn-gateway,Tags=[{Key=Name,Value=Lab-VGW}]' \
  --query 'VpnGateway.VpnGatewayId' \
  --output text)

echo "SUCCESS: VGW criado com ID: ${VGW_ID}. Aguardando ficar disponível..."
aws ec2 wait vpn-gateway-available --vpn-gateway-ids ${VGW_ID}

# Anexar o VGW à VPC
echo "INFO: Anexando VGW ${VGW_ID} à VPC ${VPC_ID}..."
aws ec2 attach-vpn-gateway \
  --vpn-gateway-id ${VGW_ID} \
  --vpc-id ${VPC_ID}

echo "SUCCESS: VGW anexado à VPC."

# --- 2. Criar o Direct Connect Gateway (DXGW) ---
echo "INFO: Criando Direct Connect Gateway (DXGW)..."
DX_GW_ID=$(aws directconnect create-direct-connect-gateway \
  --direct-connect-gateway-name Lab-DXGW \
  --amazon-side-asn ${DX_GW_ASN} \
  --query 'directConnectGateway.directConnectGatewayId' \
  --output text)

echo "SUCCESS: DXGW criado com ID: ${DX_GW_ID}"

# --- 3. Associar o VGW ao DXGW ---
echo "INFO: Associando VGW ${VGW_ID} ao DXGW ${DX_GW_ID}..."
aws directconnect create-direct-connect-gateway-association \
  --direct-connect-gateway-id ${DX_GW_ID} \
  --gateway-id ${VGW_ID} \
  --query 'directConnectGatewayAssociation.associationId' \
  --output text

echo "SUCCESS: VGW associado ao DXGW."

echo "-------------------------------------"
echo "Simulação de configuração do Direct Connect (lado AWS) concluída!"
echo "VGW ID: ${VGW_ID}"
echo "DXGW ID: ${DX_GW_ID}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Manual/Parceiro) ---"
echo "1. Crie uma conexão Direct Connect física (via console ou parceiro)."
echo "2. Crie uma Virtual Interface (VIF) Privada, associando-a ao DXGW (${DX_GW_ID})."
echo "3. Configure o roteamento BGP no seu roteador on-premises."
echo "4. Habilite a propagação de rota na tabela de rotas da sua VPC para o VGW (${VGW_ID})."

# --- Comandos de Limpeza ---

# Para desassociar o VGW do DXGW
# aws directconnect delete-direct-connect-gateway-association --association-id <ASSOCIATION_ID>

# Para deletar o DXGW
# aws directconnect delete-direct-connect-gateway --direct-connect-gateway-id ${DX_GW_ID}

# Para desanexar o VGW da VPC
# aws ec2 detach-vpn-gateway --vpn-gateway-id ${VGW_ID} --vpc-id ${VPC_ID}

# Para deletar o VGW
# aws ec2 delete-vpn-gateway --vpn-gateway-id ${VGW_ID}