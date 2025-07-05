#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Lançar um Bastion Host em uma sub-rede pública e configurar Security Groups
# para permitir acesso SSH seguro a instâncias em sub-redes privadas.

# Pré-requisitos:
# 1. Uma VPC existente (substitua <VPC_ID>).
# 2. Uma sub-rede pública existente (substitua <SUBNET_ID_PUBLICA>).
# 3. Uma sub-rede privada existente (substitua <SUBNET_ID_PRIVADA>).
# 4. Um par de chaves EC2 existente (substitua <KEY_PAIR_NAME>).
# 5. Seu IP público local (substitua <MY_LOCAL_IP>).

# Variáveis de exemplo (substitua pelos seus IDs/Nomes reais)
# VPC_ID="vpc-0abcdef1234567890"
# SUBNET_ID_PUBLICA="subnet-0abcdef1234567890"
# SUBNET_ID_PRIVADA="subnet-0abcdef1234567891"
# KEY_PAIR_NAME="my-ssh-key"
# MY_LOCAL_IP="203.0.113.10/32" # Seu IP público
# AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)

echo "--- Criando Security Group para o Bastion Host ---"

BASTION_SG_ID=$(aws ec2 create-security-group \
  --group-name BastionHostSG \
  --description "Security Group for Bastion Host" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)

# Regra de entrada: Permite SSH apenas do seu IP local
aws ec2 authorize-security-group-ingress \
  --group-id ${BASTION_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

# Regra de saída: Permite SSH para a sub-rede privada
aws ec2 authorize-security-group-egress \
  --group-id ${BASTION_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${SUBNET_ID_PRIVADA} # Ou o CIDR da sua sub-rede privada (ex: 10.0.2.0/24)

echo "BastionHostSG criado: $BASTION_SG_ID"

echo "--- Lançando a Instância do Bastion Host ---"

BASTION_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${SUBNET_ID_PUBLICA} \
  --security-group-ids ${BASTION_SG_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=BastionHost}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Bastion Host lançado com ID: $BASTION_INSTANCE_ID. Aguardando ficar em estado 'running'..."

aws ec2 wait instance-running --instance-ids $BASTION_INSTANCE_ID

BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids ${BASTION_INSTANCE_ID} \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Bastion Host está rodando. IP Público: $BASTION_PUBLIC_IP"

echo "--- Configurando Security Group da Instância Privada ---"

# Assumindo que você tem um SG para sua instância privada (ex: DB-SG)
# Substitua <PRIVATE_INSTANCE_SG_ID> pelo ID do SG da sua instância privada
# PRIVATE_INSTANCE_SG_ID="sg-0abcdef1234567890"

# Adiciona regra de entrada no SG da instância privada para permitir SSH do Bastion SG
aws ec2 authorize-security-group-ingress \
  --group-id ${PRIVATE_INSTANCE_SG_ID} \
  --protocol tcp \
  --port 22 \
  --source-group ${BASTION_SG_ID}

echo "Regra de SSH adicionada ao SG da instância privada para permitir acesso do Bastion Host."

echo "\n--- Próximos Passos (Conexão via SSH Agent Forwarding) ---"
echo "1. Adicione sua chave SSH ao agente local: ssh-add /caminho/para/${KEY_PAIR_NAME}.pem"
echo "2. Conecte-se ao Bastion Host com agent forwarding: ssh -A ec2-user@${BASTION_PUBLIC_IP}"
echo "3. Do Bastion Host, conecte-se à sua instância privada: ssh ec2-user@<IP_PRIVADO_DA_INSTANCIA_PRIVADA>"

# --- Comandos de Limpeza ---

# Para terminar a instância do Bastion Host
# aws ec2 terminate-instances --instance-ids ${BASTION_INSTANCE_ID}

# Para deletar o Security Group do Bastion Host
# aws ec2 delete-security-group --group-id ${BASTION_SG_ID}

# Para remover a regra de SSH do SG da instância privada
# aws ec2 revoke-security-group-ingress --group-id ${PRIVATE_INSTANCE_SG_ID} --protocol tcp --port 22 --source-group ${BASTION_SG_ID}