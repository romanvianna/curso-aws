#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar AWS Organizations ---

# Cenário: Este script demonstra como criar uma organização, estruturar Unidades Organizacionais (OUs),
# criar uma nova conta-membro e aplicar uma Política de Controle de Serviço (SCP).

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
# A conta que executa este script se tornará a conta de gerenciamento da Organization.
# Substitua pelo seu e-mail de teste. Use um e-mail que não esteja associado a nenhuma conta AWS existente.
NEW_ACCOUNT_EMAIL="seu.email+sandbox@example.com" # Ex: seuemail+sandbox@gmail.com
NEW_ACCOUNT_NAME="Sandbox-Account-CLI-$(date +%s)"

echo "INFO: Iniciando a configuração do AWS Organizations..."

# --- 1. Criar a Organização (se ainda não existir) ---
# Este comando só funciona se a conta atual ainda não faz parte de uma organização.
ORG_ID=$(aws organizations describe-organization --query 'Organization.Id' --output text 2>/dev/null || true)

if [ -z "$ORG_ID" ]; then
  echo "INFO: Criando nova organização..."
  ORG_ID=$(aws organizations create-organization --feature-set ALL --query 'Organization.Id' --output text)
  echo "SUCCESS: Organização criada com ID: ${ORG_ID}"
  echo "INFO: Aguardando a organização ficar ativa..."
  sleep 30 # Dar um tempo para a organização ser totalmente provisionada
else
  echo "INFO: Organização já existe com ID: ${ORG_ID}"
fi

ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
echo "Root OU ID: ${ROOT_ID}"

# --- 2. Criar a Estrutura de Unidades Organizacionais (OUs) ---
echo "INFO: Criando OUs..."

INFRA_OU_ID=$(aws organizations create-organizational-unit \
  --parent-id ${ROOT_ID} \
  --name Infrastructure \
  --query 'OrganizationalUnit.Id' \
  --output text)
echo "SUCCESS: OU Infrastructure criada: ${INFRA_OU_ID}"

WORKLOADS_OU_ID=$(aws organizations create-organizational-unit \
  --parent-id ${ROOT_ID} \
  --name Workloads \
  --query 'OrganizationalUnit.Id' \
  --output text)
echo "SUCCESS: OU Workloads criada: ${WORKLOADS_OU_ID}"

PROD_OU_ID=$(aws organizations create-organizational-unit \
  --parent-id ${WORKLOADS_OU_ID} \
  --name Production \
  --query 'OrganizationalUnit.Id' \
  --output text)
echo "SUCCESS: OU Production criada: ${PROD_OU_ID}"

DEV_OU_ID=$(aws organizations create-organizational-unit \
  --parent-id ${WORKLOADS_OU_ID} \
  --name Development \
  --query 'OrganizationalUnit.Id' \
  --output text)
echo "SUCCESS: OU Development criada: ${DEV_OU_ID}"

# --- 3. Criar uma Nova Conta-Membro ---
echo "INFO: Criando nova conta-membro (${NEW_ACCOUNT_NAME})..."
CREATE_ACCOUNT_REQUEST_ID=$(aws organizations create-account \
  --email ${NEW_ACCOUNT_EMAIL} \
  --account-name ${NEW_ACCOUNT_NAME} \
  --query 'CreateAccountStatus.Id' \
  --output text)

echo "SUCCESS: Solicitação de criação de conta enviada: ${CREATE_ACCOUNT_REQUEST_ID}. Aguardando conclusão..."

# Aguardar a conta ser criada
ACCOUNT_STATUS=$(aws organizations describe-create-account-status \
  --create-account-request-id ${CREATE_ACCOUNT_REQUEST_ID} \
  --query 'CreateAccountStatus.State' \
  --output text)

while [ "$ACCOUNT_STATUS" != "SUCCEEDED" ] && [ "$ACCOUNT_STATUS" != "FAILED" ]; do
  echo "INFO: Status da criação da conta: ${ACCOUNT_STATUS}. Aguardando..."
  sleep 10
  ACCOUNT_STATUS=$(aws organizations describe-create-account-status \
    --create-account-request-id ${CREATE_ACCOUNT_REQUEST_ID} \
    --query 'CreateAccountStatus.State' \
    --output text)
done

if [ "$ACCOUNT_STATUS" = "FAILED" ]; then
  echo "ERRO: Falha ao criar a conta. Mensagem: $(aws organizations describe-create-account-status --create-account-request-id ${CREATE_ACCOUNT_REQUEST_ID} --query 'CreateAccountStatus.FailureReason' --output text)"
  exit 1
fi

NEW_ACCOUNT_ID=$(aws organizations describe-create-account-status \
  --create-account-request-id ${CREATE_ACCOUNT_REQUEST_ID} \
  --query 'CreateAccountStatus.AccountId' \
  --output text)
echo "SUCCESS: Conta ${NEW_ACCOUNT_NAME} criada com ID: ${NEW_ACCOUNT_ID}"

# --- 4. Mover a Nova Conta para a OU Development ---
echo "INFO: Movendo conta ${NEW_ACCOUNT_ID} para a OU Development (${DEV_OU_ID})..."
aws organizations move-account \
  --account-id ${NEW_ACCOUNT_ID} \
  --source-parent-id ${ROOT_ID} \
  --destination-parent-id ${DEV_OU_ID}

echo "SUCCESS: Conta ${NEW_ACCOUNT_ID} movida para a OU Development."

# --- 5. Aplicar uma Política de Controle de Serviço (SCP) ---
echo "INFO: Criando e anexando SCP para negar acesso ao SageMaker na OU Development..."

SCP_POLICY_NAME="Deny-SageMaker-Access"
SCP_POLICY_DESCRIPTION="Denies all SageMaker actions"
SCP_POLICY_DOCUMENT='''{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Action": "sagemaker:*",
            "Resource": "*"
        }
    ]
}
'''

SCP_ID=$(aws organizations create-policy \
  --name ${SCP_POLICY_NAME} \
  --description "${SCP_POLICY_DESCRIPTION}" \
  --content "${SCP_POLICY_DOCUMENT}" \
  --type SERVICE_CONTROL_POLICY \
  --query 'Policy.PolicySummary.Id' \
  --output text)
echo "SUCCESS: SCP '${SCP_POLICY_NAME}' criada com ID: ${SCP_ID}"

# Anexar a SCP à OU Development
aws organizations attach-policy \
  --policy-id ${SCP_ID} \
  --target-id ${DEV_OU_ID}

echo "SUCCESS: SCP '${SCP_POLICY_NAME}' anexada à OU Development."

echo "-------------------------------------"
echo "Configuração do AWS Organizations concluída!"
echo "Organização ID: ${ORG_ID}"
echo "Nova Conta ID: ${NEW_ACCOUNT_ID}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação) ---"
echo "1. Verifique o e-mail (${NEW_ACCOUNT_EMAIL}) para redefinir a senha do usuário root da nova conta."
echo "2. Faça login na nova conta (${NEW_ACCOUNT_ID}) como usuário root."
echo "3. Tente acessar o console do Amazon SageMaker ou executar um comando da CLI do SageMaker (ex: aws sagemaker list-notebook-instances). Deve ser negado pela SCP."

# --- Comandos de Limpeza ---

# Para desanexar a SCP da OU
# aws organizations detach-policy --policy-id ${SCP_ID} --target-id ${DEV_OU_ID}

# Para deletar a SCP
# aws organizations delete-policy --policy-id ${SCP_ID}

# Para mover a conta de volta para a Root (necessário antes de fechar a conta)
# aws organizations move-account --account-id ${NEW_ACCOUNT_ID} --source-parent-id ${DEV_OU_ID} --destination-parent-id ${ROOT_ID}

# Para fechar a conta (requer login na conta-membro e seguir o processo de fechamento)
# aws organizations close-account --account-id ${NEW_ACCOUNT_ID}

# Para deletar as OUs (devem estar vazias)
# aws organizations delete-organizational-unit --organizational-unit-id ${DEV_OU_ID}
# aws organizations delete-organizational-unit --organizational-unit-id ${PROD_OU_ID}
# aws organizations delete-organizational-unit --organizational-unit-id ${WORKLOADS_OU_ID}
# aws organizations delete-organizational-unit --organizational-unit-id ${INFRA_OU_ID}

# Para deletar a organização (apenas se for a única conta e não houver outras contas-membro)
# aws organizations delete-organization