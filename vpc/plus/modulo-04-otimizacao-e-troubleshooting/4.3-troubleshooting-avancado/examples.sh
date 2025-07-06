#!/bin/bash

# --- Exemplo de comandos AWS CLI para Troubleshooting Avançado com Reachability Analyzer e Flow Logs ---

# Cenário: Este script demonstra como usar o VPC Reachability Analyzer para diagnosticar
# problemas de conectividade e como consultar VPC Flow Logs para análise forense.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS

# Substitua pelos IDs da sua VPC, sub-redes e Key Pair
VPC_ID="vpc-0abcdef1234567890" # Exemplo
SUBNET_A_ID="subnet-0abcdef1234567891" # Exemplo
SUBNET_B_ID="subnet-0abcdef1234567892" # Exemplo
SUBNET_A_CIDR="10.50.1.0/24" # Exemplo
SUBNET_B_CIDR="10.50.2.0/24" # Exemplo
KEY_PAIR_NAME="my-ec2-key" # Substitua pelo nome do seu Key Pair
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
MY_LOCAL_IP="203.0.113.10/32" # Substitua pelo seu IP público

echo "INFO: Iniciando a configuração do cenário de troubleshooting..."

# --- 1. Criar Security Groups para as Instâncias ---
echo "INFO: Criando Security Groups para Instance-A e Instance-B..."
SG_A_ID=$(aws ec2 create-security-group \
  --group-name SG-Instance-A \
  --description "SG for Instance A" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_A_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}
aws ec2 authorize-security-group-egress \
  --group-id ${SG_A_ID} \
  --protocol tcp \
  --port 8080 \
  --cidr ${SUBNET_B_CIDR}

SG_B_ID=$(aws ec2 create-security-group \
  --group-name SG-Instance-B \
  --description "SG for Instance B" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_B_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_B_ID} \
  --protocol tcp \
  --port 8080 \
  --cidr ${SUBNET_A_CIDR}

echo "SUCCESS: Security Groups criados: ${SG_A_ID}, ${SG_B_ID}"

# --- 2. Criar Network ACLs para as Sub-redes ---
echo "INFO: Criando Network ACLs para Subnet-A e Subnet-B..."
NACL_A_ID=$(aws ec2 create-network-acl \
  --vpc-id ${VPC_ID} \
  --query 'NetworkAcl.NetworkAclId' \
  --output text)
aws ec2 create-tags --resources ${NACL_A_ID} --tags Key=Name,Value=NACL-Subnet-A
aws ec2 associate-network-acl --network-acl-id ${NACL_A_ID} --subnet-id ${SUBNET_A_ID}

NACL_B_ID=$(aws ec2 create-network-acl \
  --vpc-id ${VPC_ID} \
  --query 'NetworkAcl.NetworkAclId' \
  --output text)
aws ec2 create-tags --resources ${NACL_B_ID} --tags Key=Name,Value=NACL-Subnet-B
aws ec2 associate-network-acl --network-acl-id ${NACL_B_ID} --subnet-id ${SUBNET_B_ID}

# Adicionar regras de ALLOW ALL para as NACLs (para não bloquear inicialmente)
aws ec2 create-network-acl-entry --network-acl-id ${NACL_A_ID} --rule-number 100 --protocol -1 --rule-action allow --ingress --cidr-block 0.0.0.0/0
aws ec2 create-network-acl-entry --network-acl-id ${NACL_A_ID} --rule-number 100 --protocol -1 --rule-action allow --egress --cidr-block 0.0.0.0/0
aws ec2 create-network-acl-entry --network-acl-id ${NACL_B_ID} --rule-number 100 --protocol -1 --rule-action allow --ingress --cidr-block 0.0.0.0/0
aws ec2 create-network-acl-entry --network-acl-id ${NACL_B_ID} --rule-number 100 --protocol -1 --rule-action allow --egress --cidr-block 0.0.0.0/0

echo "SUCCESS: Network ACLs criadas e associadas: ${NACL_A_ID}, ${NACL_B_ID}"

# --- 3. Lançar Instâncias EC2 ---
echo "INFO: Lançando Instance-A e Instance-B..."
INSTANCE_A_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${SUBNET_A_ID} \
  --security-group-ids ${SG_A_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instance-A}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

INSTANCE_B_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${SUBNET_B_ID} \
  --security-group-ids ${SG_B_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Instance-B}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "SUCCESS: Instâncias lançadas: ${INSTANCE_A_ID}, ${INSTANCE_B_ID}. Aguardando..."
aws ec2 wait instance-running --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID}

INSTANCE_A_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_A_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
INSTANCE_B_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_B_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

echo "Instance-A IP Privado: ${INSTANCE_A_PRIVATE_IP}"
echo "Instance-B IP Privado: ${INSTANCE_B_PRIVATE_IP}"

# --- 4. Injetar o Problema (Regra DENY na NACL-B) ---
echo "INFO: Injetando regra DENY na NACL-B para simular o problema..."
aws ec2 create-network-acl-entry \
  --network-acl-id ${NACL_B_ID} \
  --rule-number 90 \
  --protocol tcp \
  --rule-action deny \
  --ingress \
  --port-range From=8080,To=8080 \
  --cidr-block ${SUBNET_A_CIDR}

echo "SUCCESS: Regra DENY adicionada à NACL-B. A conectividade para a porta 8080 deve estar quebrada."

echo "-------------------------------------"
echo "Cenário de Troubleshooting configurado!"
echo "-------------------------------------"

echo "\n--- Próximos Passos (Diagnóstico) ---"
echo "1. Vá para o console da AWS -> VPC -> Reachability Analyzer."
echo "2. Crie uma nova análise de caminho:"
echo "   - Origem: Instância ${INSTANCE_A_ID}"
echo "   - Destino: Instância ${INSTANCE_B_ID}"
echo "   - Protocolo: TCP, Porta: 8080"
echo "3. Analise o resultado. Ele deve indicar 'Not reachable' e apontar a regra DENY na NACL-B como o problema."
echo "4. Para corrigir, remova a regra DENY (Rule #90) da NACL-B no console ou via CLI."
echo "   aws ec2 delete-network-acl-entry --network-acl-id ${NACL_B_ID} --rule-number 90 --ingress"
echo "5. Reanalise o caminho no Reachability Analyzer (deve estar 'Reachable')."

# --- Comandos de Limpeza ---

# Para terminar as instâncias
# aws ec2 terminate-instances --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID}
# aws ec2 wait instance-terminated --instance-ids ${INSTANCE_A_ID} ${INSTANCE_B_ID}

# Para deletar as regras das NACLs (se não forem as padrão)
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_A_ID} --rule-number 100 --protocol -1 --rule-action allow --ingress --cidr-block 0.0.0.0/0
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_A_ID} --rule-number 100 --protocol -1 --rule-action allow --egress --cidr-block 0.0.0.0/0
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_B_ID} --rule-number 100 --protocol -1 --rule-action allow --ingress --cidr-block 0.0.0.0/0
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_B_ID} --rule-number 100 --protocol -1 --rule-action allow --egress --cidr-block 0.0.0.0/0
# aws ec2 delete-network-acl-entry --network-acl-id ${NACL_B_ID} --rule-number 90 --ingress # Se ainda existir

# Para deletar as NACLs customizadas
# aws ec2 delete-network-acl --network-acl-id ${NACL_A_ID}
# aws ec2 delete-network-acl --network-acl-id ${NACL_B_ID}

# Para deletar os Security Groups
# aws ec2 delete-security-group --group-id ${SG_A_ID}
# aws ec2 delete-security-group --group-id ${SG_B_ID}

# Para deletar as sub-redes
# aws ec2 delete-subnet --subnet-id ${SUBNET_A_ID}
# aws ec2 delete-subnet --subnet-id ${SUBNET_B_ID}

# Para deletar a VPC
# aws ec2 delete-vpc --vpc-id ${VPC_ID}