#!/bin/bash

# --- Exemplo de uso de Módulos Terraform (Comandos Básicos) ---

# Este script demonstra o fluxo de trabalho para usar um módulo Terraform.
# Assumimos que você já tem um módulo definido em um subdiretório (ex: ./modules/vpc).

# Pré-requisitos:
# 1. Terraform CLI instalado.
# 2. Um projeto Terraform com um módulo definido (conforme o README.md).
# 3. AWS CLI configurada com credenciais de acesso.

# Navegue para o diretório raiz do seu projeto Terraform
# cd /caminho/para/seu/projeto/terraform

echo "--- 1. Inicializando o diretório Terraform (com módulos) ---"
# O 'init' detectará e baixará os provedores e inicializará os módulos.
terraform init

if [ $? -ne 0 ]; then
  echo "ERRO: terraform init falhou. Verifique a configuração do módulo e provedores."
  exit 1
fi

echo "--- 2. Validando a configuração do Terraform ---"
# Verifica a sintaxe e a validade dos arquivos .tf, incluindo a chamada ao módulo.
terraform validate

if [ $? -ne 0 ]; then
  echo "ERRO: terraform validate falhou. Corrija os erros de sintaxe."
  exit 1
fi

echo "--- 3. Gerando um plano de execução do Terraform ---"
# Mostra o que o Terraform fará, incluindo os recursos criados pelo módulo.
terraform plan -out tfplan.out

if [ $? -ne 0 ]; then
  echo "ERRO: terraform plan falhou. Verifique o plano e as dependências do módulo."
  exit 1
fi

echo "--- 4. Aplicando as mudanças do Terraform ---"
# Executa as ações definidas no plano, provisionando a infraestrutura via módulo.
terraform apply tfplan.out

if [ $? -ne 0 ]; then
  echo "ERRO: terraform apply falhou. Verifique os logs."
  exit 1
fi

echo "SUCCESS: Infraestrutura provisionada com sucesso usando o módulo!"

echo "\n--- 5. Destruindo a infraestrutura do Terraform (Opcional) ---"
# Remove todos os recursos gerenciados pelo Terraform, incluindo os criados pelo módulo.
read -p "Deseja destruir a infraestrutura criada pelo módulo? (y/N): " CONFIRM_DESTROY
if [[ "$CONFIRM_DESTROY" =~ ^[yY]$ ]]; then
  terraform destroy -auto-approve
  if [ $? -ne 0 ]; then
    echo "ERRO: terraform destroy falhou."
    exit 1
  fi
  echo "SUCCESS: Infraestrutura destruída com sucesso!"
else
  echo "Destruição cancelada."
fi