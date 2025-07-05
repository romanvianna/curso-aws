#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Demonstrar o Controle de Acesso Baseado em Atributos (ABAC) no IAM.
# Criaremos uma política que permite iniciar/parar instâncias EC2 apenas se a tag 'Project'
# da instância corresponder à tag 'Project' da role que está realizando a ação.

# Pré-requisitos:
# 1. Instâncias EC2 existentes com a tag 'Project' (ex: Project: Helio, Project: Artemis).
# 2. Uma conta AWS com permissões para criar políticas e roles IAM.

# Variáveis de exemplo (substitua pelos seus valores reais)
# INSTANCE_ID_HELIO="i-0abcdef1234567890" # ID de uma instância com Project: Helio
# INSTANCE_ID_ARTEMIS="i-0abcdef1234567891" # ID de uma instância com Project: Artemis

echo "--- Criando Política IAM com ABAC ---"

# Definição da política IAM em JSON
# Esta política permite 'DescribeInstances' para listar todas as instâncias,
# mas restringe 'StopInstances', 'StartInstances', 'RebootInstances'
# apenas para instâncias onde a tag 'Project' do recurso é igual à tag 'Project' do principal.
POLICY_JSON='''{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowListing",
            "Effect": "Allow",
            "Action": "ec2:DescribeInstances",
            "Resource": "*"
        },
        {
            "Sid": "AllowStartStopInstancesByProjectTag",
            "Effect": "Allow",
            "Action": [
                "ec2:StopInstances",
                "ec2:StartInstances",
                "ec2:RebootInstances"
            ],
            "Resource": "arn:aws:ec2:*:*:instance/*",
            "Condition": {
                "StringEquals": {
                    "ec2:ResourceTag/Project": "${aws:PrincipalTag/Project}"
                }
            }
        }
    ]
}
'''

# Cria a política IAM
POLICY_ARN=$(aws iam create-policy \
  --policy-name Developer-Project-Access-Policy \
  --policy-document "$POLICY_JSON" \
  --query 'Policy.Arn' \
  --output text)

echo "Política 'Developer-Project-Access-Policy' criada com ARN: $POLICY_ARN"

echo "--- Criando Role IAM para o Projeto Helio ---"

# Definição da Trust Policy para a Role
TRUST_POLICY_JSON='''{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<YOUR_ACCOUNT_ID>:root" # Substitua pelo seu Account ID
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'''

# Cria a Role
ROLE_ARN=$(aws iam create-role \
  --role-name Developer-Role-Helio \
  --assume-role-policy-document "$TRUST_POLICY_JSON" \
  --query 'Role.Arn' \
  --output text)

echo "Role 'Developer-Role-Helio' criada com ARN: $ROLE_ARN"

# Anexa a política de acesso à Role
aws iam attach-role-policy \
  --role-name Developer-Role-Helio \
  --policy-arn ${POLICY_ARN}

echo "Política anexada à Role."

# Adiciona a tag 'Project: Helio' à Role
aws iam tag-role \
  --role-name Developer-Role-Helio \
  --tags Key=Project,Value=Helio

echo "Tag 'Project: Helio' adicionada à Role 'Developer-Role-Helio'."

echo "\n--- Teste de Validação (Manual) ---"
echo "1. Vá para o console da AWS e use 'Switch Role' para assumir a role 'Developer-Role-Helio'."
echo "2. No console EC2, tente parar a instância com a tag 'Project: Helio' (deve funcionar)."
echo "3. No console EC2, tente parar a instância com a tag 'Project: Artemis' (deve falhar com erro de autorização)."

# --- Comandos de Limpeza ---

# Para desanexar a política da role
# aws iam detach-role-policy --role-name Developer-Role-Helio --policy-arn ${POLICY_ARN}

# Para deletar a role
# aws iam delete-role --role-name Developer-Role-Helio

# Para deletar a política
# aws iam delete-policy --policy-arn ${POLICY_ARN}