# Módulo 4.1: AWS CLI Avançado e Scripts de Automação

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Objetivos

- Entender a automação de infraestrutura como um pilar do DevOps e da Nuvem.
- Aprender a usar a AWS CLI de forma programática, utilizando filtros do lado do servidor e queries do lado do cliente.
- Escrever scripts de automação em Bash para realizar tarefas de provisionamento de forma repetível e consistente.

---

## 1. Automação Imperativa vs. Declarativa (Teoria - 45 min)

À medida que os ambientes de nuvem crescem, a configuração manual se torna o maior gargalo para a velocidade e a principal fonte de erros. A **automação** é a solução. Existem duas abordagens principais para a automação da infraestrutura:

1.  **Abordagem Imperativa ("Como Fazer"):
    -   **Conceito:** Você escreve um script que especifica a **sequência exata de comandos** a serem executados para alcançar o estado desejado. Você diz à máquina *como* fazer algo, passo a passo.
    -   **Exemplo:** "Primeiro, execute o comando `create-vpc`. Depois, pegue o ID da VPC retornada. Em seguida, execute o comando `create-subnet` usando esse ID..."
    -   **Ferramentas:** Scripts em Bash, Python (usando SDKs como o Boto3) ou PowerShell, que chamam a **AWS CLI**, são exemplos de automação imperativa.
    -   **Vantagens:** Oferece controle total e granular sobre o processo. É ótimo para tarefas de orquestração complexas.
    -   **Desvantagens:** O script é responsável por lidar com a lógica de estado. O que acontece se o script falhar no meio? Ele sabe como continuar de onde parou ou como limpar os recursos já criados? Manter o estado pode ser complexo.

2.  **Abordagem Declarativa ("O Que Fazer"):
    -   **Conceito:** Você escreve um arquivo de definição que descreve o **estado final desejado** da sua infraestrutura. Você diz à máquina *o que* você quer, não como chegar lá.
    -   **Exemplo:** "Eu quero que exista uma VPC com este CIDR e uma sub-rede com aquele CIDR."
    -   **Ferramentas:** Ferramentas de Infraestrutura como Código (IaC) como **Terraform** e **AWS CloudFormation** usam uma abordagem declarativa.
    -   **Vantagens:** A ferramenta é responsável por gerenciar o estado. Ela compara o estado desejado com o estado atual e descobre quais ações (criar, atualizar, deletar) são necessárias para reconciliá-los. Isso torna as operações muito mais robustas e previsíveis.

Neste módulo, vamos focar na abordagem **imperativa** usando a AWS CLI, que é um excelente ponto de partida para a automação e um pré-requisito para entender problemas mais complexos que as ferramentas declarativas resolvem.

### Dominando a AWS CLI para Scripts

Para usar a CLI de forma eficaz em scripts, é preciso dominar o processamento de sua saída.

-   **Filtros (`--filters`):
    -   Esta é uma otimização crucial. A filtragem ocorre **do lado do servidor**. Em vez de pedir à AWS para lhe enviar uma lista de 5000 instâncias e depois processá-la localmente, você pede à API para lhe enviar apenas as instâncias que correspondem aos seus critérios (ex: `Name=tag:Project,Values=Blue`). Isso economiza largura de banda e acelera seus scripts.

-   **Queries (`--query`):
    -   Esta operação ocorre **do lado do cliente**. Após receber a resposta JSON da API (já filtrada, se for o caso), você pode usar a flag `--query` para extrair apenas os campos específicos de que precisa. Ela usa a sintaxe **JMESPath**.

-   **Saída (`--output text`):
    -   Ao extrair um único valor (como um ID) para ser usado em um comando subsequente, o formato `text` é essencial. Ele retorna o valor bruto, sem as aspas do JSON, tornando-o perfeito para ser atribuído a uma variável de shell.

---

## 2. Criação de Scripts para Deployment (Prática - 75 min)

Neste laboratório, vamos escrever um script Bash que automatiza a criação de uma VPC funcional, aplicando os conceitos de captura de IDs e encadeamento de comandos.

### Cenário

Vamos criar um script chamado `provision_vpc.sh` que, quando executado, provisiona uma VPC com uma sub-rede pública, um IGW e uma tabela de rotas pública. Isso transforma um processo manual de 10 minutos em um comando de 10 segundos.

### Roteiro Prático

**Passo 1: Criar o Arquivo de Script**
1.  Em sua máquina local ou em uma instância EC2, crie e torne executável um novo arquivo:
    `touch provision_vpc.sh`
    `chmod +x provision_vpc.sh`
2.  Abra o arquivo em um editor de texto.

**Passo 2: Escrever o Script Bash Imperativo**
Copie e cole o seguinte código no seu arquivo. Cada comando é um passo explícito na nossa receita de provisionamento.

```bash
#!/bin/bash

# Script imperativo para criar uma VPC básica.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Mude para a sua região, se necessário
VPC_NAME="Cli-VPC"
VPC_CIDR="10.100.0.0/16"
SUBNET_CIDR="10.100.1.0/24"

echo "INFO: Iniciando o provisionamento da VPC '${VPC_NAME}' na região ${AWS_REGION}..."

# --- Etapa 1: Criar a VPC ---
echo "INFO: Criando a VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --query "Vpc.VpcId" \
  --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME
echo "SUCCESS: VPC criada com ID: $VPC_ID"

# --- Etapa 2: Criar a Sub-rede ---
echo "INFO: Criando a Sub-rede..."
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_CIDR \
  --query "Subnet.SubnetId" \
  --output text)
aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=${VPC_NAME}-Public-Subnet
echo "SUCCESS: Sub-rede criada com ID: $SUBNET_ID"

# --- Etapa 3: Criar e Anexar o Internet Gateway ---
echo "INFO: Criando e anexando o Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=${VPC_NAME}-IGW
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
echo "SUCCESS: Internet Gateway criado e anexado: $IGW_ID"

# --- Etapa 4: Criar e Configurar a Tabela de Rotas ---
echo "INFO: Criando e configurando a Tabela de Rotas..."
# A VPC já vem com uma tabela de rotas principal. Vamos usá-la.
RT_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --query "RouteTables[0].RouteTableId" --output text)
aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=${VPC_NAME}-Public-RT

# Criar a rota para a Internet
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID > /dev/null
echo "INFO: Rota para a internet adicionada à tabela ${RT_ID}"

# Associar a Tabela de Rotas à Sub-rede
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RT_ID > /dev/null
echo "INFO: Sub-rede ${SUBNET_ID} associada à tabela de rotas ${RT_ID}"

echo "-------------------------------------"
echo "Provisionamento da VPC concluído!"
echo "VPC ID: ${VPC_ID}"
echo "-------------------------------------"

```

**Passo 3: Executar e Validar**
1.  Certifique-se de que sua AWS CLI está configurada com as permissões necessárias.
2.  Execute o script: `./provision_vpc.sh`
3.  Observe a saída, que mostra a execução de cada etapa.
4.  **Validação:**
    -   Vá para o console da VPC.
    -   Você verá a nova `Cli-VPC` com todos os seus componentes: a sub-rede, o IGW e a tabela de rotas configurada e associada corretamente.

**Passo 4: Desafio (Script de Limpeza)**
-   Crie um script `destroy_vpc.sh` que aceite um `VPC_ID` como argumento e execute os comandos `delete-*` na ordem inversa para limpar os recursos. Isso reforça a ideia de que, na automação imperativa, você é responsável por gerenciar tanto a criação quanto a destruição.

Este laboratório demonstra como a automação imperativa com a AWS CLI, embora mais verbosa que as ferramentas declarativas, fornece controle total e é um passo fundamental para a automação da nuvem.