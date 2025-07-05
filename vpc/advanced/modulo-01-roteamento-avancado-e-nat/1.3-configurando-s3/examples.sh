#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Criar um bucket S3 e aplicar uma política de bucket para restringir o acesso
# apenas a partir de um IP de origem específico (simulando o EIP de um NAT Gateway).

# Pré-requisitos:
# 1. Um Elastic IP (EIP) associado a um NAT Gateway na sua VPC.
# 2. Uma instância EC2 em uma sub-rede privada com acesso à internet via NAT Gateway.
# 3. Uma IAM Role anexada à instância EC2 com permissões para o S3.

# Variáveis de exemplo (substitua pelos seus valores reais)
# BUCKET_NAME="my-secure-app-logs-$(date +%s)" # Nome único para o bucket
# NAT_GATEWAY_EIP="203.0.113.125" # Substitua pelo EIP do seu NAT Gateway
# INSTANCE_ID="i-0abcdef1234567890" # Substitua pelo ID da sua instância EC2 privada

echo "Criando bucket S3: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME

echo "Aplicando política de bucket para restringir acesso ao IP $NAT_GATEWAY_EIP"
# A política nega todo o acesso, exceto se a requisição vier do IP especificado.
BUCKET_POLICY='''{
    "Version": "2012-10-17",
    "Id": "PolicyForNATIP",
    "Statement": [
        {
            "Sid": "DenyAccessUnlessFromNAT",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::'$BUCKET_NAME'",
                "arn:aws:s3:::'$BUCKET_NAME'/*"
            ],
            "Condition": {
                "NotIpAddress": {
                    "aws:SourceIp": "'$NAT_GATEWAY_EIP'/32"
                }
            }
        }
    ]
}
'''

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "$BUCKET_POLICY"

echo "Política de bucket aplicada com sucesso."

echo "\n--- Testando acesso do IP autorizado (simulando instância via NAT Gateway) ---"
# Para testar isso via CLI, você precisaria executar este comando de uma máquina
# cujo IP público seja o mesmo do NAT Gateway, ou de uma instância EC2 na VPC.
# Exemplo de comando a ser executado na instância EC2:
# ssh -i your-key.pem ec2-user@<BASTION_HOST_IP>
# ssh -i your-key.pem ec2-user@<PRIVATE_INSTANCE_IP>
# echo "Hello from private instance" > test-file.txt
# aws s3 cp test-file.txt s3://$BUCKET_NAME/test-file.txt

# Exemplo de como você pode simular o acesso (requer que o EIP do NAT GW seja o IP da sua máquina local)
# echo "Conteúdo de teste" > local-test.txt
# aws s3 cp local-test.txt s3://$BUCKET_NAME/local-test.txt

echo "\n--- Testando acesso de um IP não autorizado (simulando máquina local diferente) ---"
# Este comando deve falhar com "Access Denied" se executado de um IP diferente do NAT_GATEWAY_EIP.
# aws s3 ls s3://$BUCKET_NAME

echo "\nPara validar, tente fazer upload/download do bucket a partir da sua instância EC2 privada e de sua máquina local."

# --- Comandos de Limpeza ---

# Para remover todos os objetos do bucket antes de deletá-lo
# aws s3 rm s3://$BUCKET_NAME --recursive

# Para deletar o bucket
# aws s3 rb s3://$BUCKET_NAME