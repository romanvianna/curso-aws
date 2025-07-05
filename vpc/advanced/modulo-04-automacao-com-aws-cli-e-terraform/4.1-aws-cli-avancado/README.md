# Módulo 4.1: AWS CLI Avançado e Scripts de Automação

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Pré-requisitos

*   Conhecimento básico de linha de comando (Bash).
*   Familiaridade com os serviços AWS (VPC, EC2).
*   AWS CLI instalada e configurada com credenciais de acesso.

## Objetivos

*   Entender a automação de infraestrutura como um pilar do DevOps e da Nuvem.
*   Aprender a usar a AWS CLI de forma programática, utilizando filtros do lado do servidor e queries JMESPath do lado do cliente.
*   Escrever scripts de automação em Bash para realizar tarefas de provisionamento e gerenciamento de forma repetível e consistente.
*   Discutir cenários de uso da AWS CLI em ambientes de produção para automação de tarefas operacionais.

---

## 1. Automação Imperativa vs. Declarativa (Teoria - 45 min)

À medida que os ambientes de nuvem crescem, a configuração manual se torna o maior gargalo para a velocidade, a consistência e a principal fonte de erros. A **automação** é a solução. Existem duas abordagens principais para a automação da infraestrutura:

1.  **Abordagem Imperativa ("Como Fazer"):
    *   **Conceito:** Você escreve um script que especifica a **sequência exata de comandos** a serem executados para alcançar o estado desejado. Você diz à máquina *como* fazer algo, passo a passo.
    *   **Exemplo:** "Primeiro, execute o comando `create-vpc`. Depois, pegue o ID da VPC retornada. Em seguida, execute o comando `create-subnet` usando esse ID..."
    *   **Ferramentas:** Scripts em Bash, Python (usando SDKs como o Boto3) ou PowerShell, que chamam a **AWS CLI**, são exemplos de automação imperativa.
    *   **Vantagens:** Oferece controle total e granular sobre o processo. É ótimo para tarefas de orquestração complexas, automação de tarefas pontuais, ou para integrar com sistemas existentes.
    *   **Desvantagens:** O script é responsável por lidar com a lógica de estado. O que acontece se o script falhar no meio? Ele sabe como continuar de onde parou ou como limpar os recursos já criados? Manter o estado pode ser complexo e propenso a erros (drift de configuração).

2.  **Abordagem Declarativa ("O Que Fazer"):
    *   **Conceito:** Você escreve um arquivo de definição que descreve o **estado final desejado** da sua infraestrutura. Você diz à máquina *o que* você quer, não como chegar lá. A ferramenta se encarrega de descobrir os passos necessários para atingir esse estado.
    *   **Exemplo:** "Eu quero que exista uma VPC com este CIDR e uma sub-rede com aquele CIDR."
    *   **Ferramentas:** Ferramentas de Infraestrutura como Código (IaC) como **Terraform** e **AWS CloudFormation** usam uma abordagem declarativa.
    *   **Vantagens:** A ferramenta é responsável por gerenciar o estado. Ela compara o estado desejado com o estado atual e descobre quais ações (criar, atualizar, deletar) são necessárias para reconciliá-los. Isso torna as operações muito mais robustas, previsíveis e idempotentes (executar o mesmo código várias vezes resulta no mesmo estado).

Neste módulo, vamos focar na abordagem **imperativa** usando a AWS CLI, que é um excelente ponto de partida para a automação e um pré-requisito para entender problemas mais complexos que as ferramentas declarativas resolvem. A AWS CLI é fundamental para interações rápidas e para construir scripts personalizados.

### Dominando a AWS CLI para Scripts

Para usar a CLI de forma eficaz em scripts, é preciso dominar o processamento de sua saída, que por padrão é JSON.

*   **Filtros (`--filters`):
    *   Esta é uma otimização crucial. A filtragem ocorre **do lado do servidor**. Em vez de pedir à AWS para lhe enviar uma lista de 5000 instâncias e depois processá-la localmente, você pede à API para lhe enviar apenas as instâncias que correspondem aos seus critérios (ex: `Name=tag:Project,Values=Blue`). Isso economiza largura de banda, acelera seus scripts e reduz a carga na sua máquina local.

*   **Queries (`--query`):
    *   Esta operação ocorre **do lado do cliente**. Após receber a resposta JSON da API (já filtrada, se for o caso), você pode usar a flag `--query` para extrair apenas os campos específicos de que precisa. Ela usa a sintaxe **JMESPath**, uma linguagem de consulta para JSON. Isso é extremamente útil para extrair IDs de recursos recém-criados ou informações específicas de uma lista.
    *   *Exemplo:* `--query "Vpcs[0].VpcId"` para pegar o ID da primeira VPC retornada.

*   **Saída (`--output text` ou `--output json`):
    *   `--output text`: Ao extrair um único valor (como um ID) para ser usado em um comando subsequente, o formato `text` é essencial. Ele retorna o valor bruto, sem as aspas do JSON, tornando-o perfeito para ser atribuído a uma variável de shell.
    *   `--output json`: O formato padrão. Útil quando você precisa processar a saída com ferramentas como `jq` para manipulações mais complexas de JSON.

---

## 2. Criação de Scripts para Deployment (Prática - 75 min)

Neste laboratório, vamos escrever um script Bash que automatiza a criação de uma VPC funcional, aplicando os conceitos de captura de IDs e encadeamento de comandos. Isso simula um cenário onde um engenheiro DevOps precisa provisionar rapidamente um ambiente de desenvolvimento ou teste.

### Cenário: Provisionamento Rápido de Ambiente de Desenvolvimento

Uma equipe de desenvolvimento precisa de ambientes de VPC isolados para testar novas funcionalidades. Em vez de provisionar manualmente cada VPC, um script AWS CLI será criado para automatizar a criação de uma VPC básica com sub-rede pública, Internet Gateway e tabela de rotas, garantindo consistência e agilidade.

### Roteiro Prático

**Passo 1: Criar o Arquivo de Script**
1.  Em sua máquina local ou em uma instância EC2 com AWS CLI configurada, crie e torne executável um novo arquivo:
    `touch provision_vpc.sh`
    `chmod +x provision_vpc.sh`
2.  Abra o arquivo em um editor de texto.

**Passo 2: Escrever o Script Bash Imperativo**
Copie e cole o seguinte código no seu arquivo. Cada comando é um passo explícito na nossa receita de provisionamento. O uso de `set -e` é crucial para garantir que o script pare em caso de erro.

```bash
#!/bin/bash

# Script imperativo para criar uma VPC básica com sub-rede pública e IGW.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Mude para a sua região, se necessário
VPC_NAME="Cli-VPC-$(date +%s)" # Nome único para a VPC
VPC_CIDR="10.100.0.0/16"
SUBNET_CIDR="10.100.1.0/24"
AVAILABILITY_ZONE="us-east-1a" # Escolha uma AZ na sua região

echo "INFO: Iniciando o provisionamento da VPC '${VPC_NAME}' na região ${AWS_REGION}..."

# --- Etapa 1: Criar a VPC ---
echo "INFO: Criando a VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${VPC_NAME}}]" \
  --query "Vpc.VpcId" \
  --output text)

echo "SUCCESS: VPC criada com ID: $VPC_ID"

# --- Etapa 2: Criar a Sub-rede Pública ---
echo "INFO: Criando a Sub-rede pública..."
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_CIDR \
  --availability-zone $AVAILABILITY_ZONE \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${VPC_NAME}-Public-Subnet}]" \
  --query "Subnet.SubnetId" \
  --output text)

echo "SUCCESS: Sub-rede pública criada com ID: $SUBNET_ID"

# Habilitar auto-assign de IPs públicos para a sub-rede
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch

echo "INFO: Auto-assign de IPs públicos habilitado para a sub-rede ${SUBNET_ID}"

# --- Etapa 3: Criar e Anexar o Internet Gateway ---
echo "INFO: Criando e anexando o Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${VPC_NAME}-IGW}]" \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

echo "SUCCESS: Internet Gateway criado e anexado: $IGW_ID"

# --- Etapa 4: Criar e Configurar a Tabela de Rotas Pública ---
echo "INFO: Criando e configurando a Tabela de Rotas pública..."

# A VPC já vem com uma tabela de rotas principal. Vamos usá-la ou criar uma nova.
# Para este exemplo, vamos criar uma nova e associá-la explicitamente.
PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${VPC_NAME}-Public-RT}]" \
  --query "RouteTable.RouteTableId" \
  --output text)

echo "SUCCESS: Tabela de Rotas pública criada: ${PUBLIC_RT_ID}"

# Criar a rota padrão para a Internet (0.0.0.0/0) via IGW
aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID > /dev/null

echo "INFO: Rota padrão para a internet adicionada à tabela ${PUBLIC_RT_ID}"

# Associar a Tabela de Rotas à Sub-rede Pública
aws ec2 associate-route-table \
  --subnet-id $SUBNET_ID \
  --route-table-id $PUBLIC_RT_ID > /dev/null

echo "INFO: Sub-rede ${SUBNET_ID} associada à tabela de rotas ${PUBLIC_RT_ID}"

echo "-------------------------------------"
echo "Provisionamento da VPC concluído!"
echo "VPC ID: ${VPC_ID}"
echo "Subnet ID: ${SUBNET_ID}"
echo "Internet Gateway ID: ${IGW_ID}"
echo "Route Table ID: ${PUBLIC_RT_ID}"
echo "-------------------------------------"

```

**Passo 3: Executar e Validar**
1.  Certifique-se de que sua AWS CLI está configurada com as permissões necessárias para criar e gerenciar recursos de VPC.
2.  Execute o script: `./provision_vpc.sh`
3.  Observe a saída, que mostra a execução de cada etapa e os IDs dos recursos criados.
4.  **Validação:**
    *   Vá para o console da AWS VPC.
    *   Você verá a nova VPC com o nome `Cli-VPC-xxxxxxxxxx` (o sufixo será um timestamp) com todos os seus componentes: a sub-rede pública, o Internet Gateway anexado e a tabela de rotas configurada e associada corretamente.
    *   Tente lançar uma instância EC2 na sub-rede pública e verifique se ela consegue acessar a internet.

**Passo 4: Desafio (Script de Limpeza)**

Crie um script `destroy_vpc.sh` que aceite o `VPC_ID` como argumento e execute os comandos `delete-*` na ordem inversa para limpar os recursos. Isso reforça a ideia de que, na automação imperativa, você é responsável por gerenciar tanto a criação quanto a destruição, e a ordem é crucial para evitar erros de dependência.

```bash
#!/bin/bash

# Script imperativo para destruir uma VPC criada pelo provision_vpc.sh.

set -e # Encerra o script imediatamente se um comando falhar

if [ -z "$1" ]; then
  echo "Uso: $0 <VPC_ID>"
  exit 1
fi

VPC_ID=$1

echo "INFO: Iniciando a destruição da VPC ${VPC_ID}..."

# 1. Desassociar e deletar a tabela de rotas (se não for a principal)
# Primeiro, encontre as associações de sub-rede e desassocie-as
ASSOCIATIONS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --query "RouteTables[].Associations[?Main != `true`].RouteTableAssociationId" --output text)
for ASSOC_ID in $ASSOCIATIONS; do
  echo "INFO: Desassociando tabela de rotas ${ASSOC_ID}..."
  aws ec2 disassociate-route-table --association-id $ASSOC_ID
done

# Encontre e delete as rotas (exceto a rota local)
ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --query "RouteTables[].RouteTableId" --output text)
for RT_ID in $ROUTE_TABLE_IDS; do
  echo "INFO: Deletando rotas da tabela ${RT_ID}..."
  ROUTES=$(aws ec2 describe-route-tables --route-table-ids ${RT_ID} --query "RouteTables[0].Routes[?Origin != `CreateRouteTable`].DestinationCidrBlock" --output text)
  for DEST_CIDR in $ROUTES; do
    echo "INFO: Deletando rota ${DEST_CIDR} da tabela ${RT_ID}"
    aws ec2 delete-route --route-table-id ${RT_ID} --destination-cidr-block ${DEST_CIDR}
  done
  # Se a tabela de rotas não for a principal, delete-a
  IS_MAIN=$(aws ec2 describe-route-tables --route-table-ids ${RT_ID} --query "RouteTables[0].Associations[0].Main" --output text)
  if [ "$IS_MAIN" != "true" ]; then
    echo "INFO: Deletando tabela de rotas ${RT_ID}..."
    aws ec2 delete-route-table --route-table-id ${RT_ID}
  fi
done

# 2. Deletar sub-redes
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --query "Subnets[].SubnetId" --output text)
for SUBNET_ID in $SUBNET_IDS; do
  echo "INFO: Deletando sub-rede ${SUBNET_ID}..."
  aws ec2 delete-subnet --subnet-id $SUBNET_ID
done

# 3. Desanexar e deletar Internet Gateway
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${VPC_ID}" --query "InternetGateways[0].InternetGatewayId" --output text)
if [ -n "$IGW_ID" ]; then
  echo "INFO: Desanexando Internet Gateway ${IGW_ID} da VPC ${VPC_ID}..."
  aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
  echo "INFO: Deletando Internet Gateway ${IGW_ID}..."
  aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
else
  echo "INFO: Nenhum Internet Gateway encontrado para a VPC ${VPC_ID}."
fi

# 4. Deletar a VPC
echo "INFO: Deletando VPC ${VPC_ID}..."
aws ec2 delete-vpc --vpc-id $VPC_ID

echo "SUCCESS: VPC ${VPC_ID} e seus recursos associados foram deletados."
```

Este laboratório demonstra como a automação imperativa com a AWS CLI, embora mais verbosa que as ferramentas declarativas, fornece controle total e é um passo fundamental para a automação da nuvem.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Use `set -e`:** Sempre inclua `set -e` no início dos seus scripts Bash para garantir que o script saia imediatamente se qualquer comando falhar. Isso evita que o script continue executando com um estado inesperado.
*   **Tratamento de Erros:** Implemente tratamento de erros mais robusto usando blocos `if/else` e `trap` para lidar com falhas de forma graciosa e fornecer mensagens de erro claras.
*   **Idempotência:** Tente tornar seus scripts o mais idempotentes possível. Isso significa que executar o script várias vezes deve produzir o mesmo resultado, sem efeitos colaterais indesejados. Embora mais difícil com scripts imperativos, é uma boa prática a ser buscada.
*   **Variáveis e Parâmetros:** Use variáveis para parâmetros configuráveis (IDs, nomes, CIDRs) e passe-os como argumentos para o script ou leia de um arquivo de configuração. Evite "hard-coding" de valores.
*   **Saída JSON e JMESPath:** Sempre que possível, use `--output json` e processe a saída com `jq` para extrair informações de forma confiável. Para extrações simples, `--output text` com `--query` é eficiente.
*   **Logging:** Adicione mensagens de log informativas (`echo "INFO: ..."`, `echo "ERROR: ..."`) para acompanhar o progresso do script e depurar problemas.
*   **Dry Run:** Para scripts que fazem alterações significativas, considere adicionar um modo "dry run" que apenas mostra o que seria feito sem realmente executar os comandos.
*   **IAM Least Privilege:** Configure as credenciais da AWS CLI com o princípio do menor privilégio, concedendo apenas as permissões necessárias para as ações que o script irá executar.
*   **Versionamento:** Mantenha seus scripts de automação sob controle de versão (Git) para rastrear alterações, colaborar com a equipe e reverter para versões anteriores, se necessário.
*   **Documentação:** Documente seus scripts, explicando seu propósito, pré-requisitos, como usar e como limpar os recursos criados.
