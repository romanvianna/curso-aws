# Módulo 4.3: Introdução ao AWS CLI para VPC

**Tempo de Aula:** 30 minutos de teoria, 30 minutos de prática

## Pré-requisitos

*   Conhecimento básico de linha de comando (terminal, Bash/PowerShell).
*   Familiaridade com os conceitos de VPC e seus componentes (Módulos 1.1, 1.3).
*   AWS CLI instalada e configurada com credenciais de acesso (via `aws configure` ou IAM Role).

## Objetivos

*   Entender a AWS CLI como uma interface programática para interagir com os serviços da AWS, além do console gráfico.
*   Aprender a estrutura de comandos da CLI e como ela mapeia para as ações da API da AWS.
*   Executar comandos essenciais para inspecionar e descrever componentes da VPC (VPC, sub-redes, IGW, tabelas de rotas, SGs, NACLs) via linha de comando.
*   Compreender a importância das flags `--query` e `--output` para processar a saída da CLI.
*   Discutir a relevância da AWS CLI para automação e Infraestrutura como Código.

---

## 1. Gerenciando a AWS via Linha de Comando (Teoria - 30 min)

Até agora, interagimos com a AWS através do Console de Gerenciamento, uma interface gráfica (GUI). Embora seja ótima para aprendizado e visualização, em ambientes profissionais, a automação e a eficiência exigem uma interface programática. A principal ferramenta para isso é a **AWS Command Line Interface (CLI)**.

### O que é uma CLI e por que usá-la?

Uma **Interface de Linha de Comando (CLI)** é um programa baseado em texto que aceita comandos como entrada para interagir com um sistema. Em vez de clicar em botões, você digita comandos.

**Por que usar a AWS CLI?**

*   **Automação e Scripting:** Este é o motivo mais importante. A CLI é a base para a automação. Você pode escrever scripts (em Bash, Python, PowerShell, etc.) que chamam comandos da CLI para provisionar, configurar e gerenciar recursos de forma repetível e consistente. Isso é o coração da Infraestrutura como Código (IaC) e do DevOps.
*   **Eficiência e Velocidade:** Para tarefas repetitivas ou para obter informações específicas, executar um único comando é muito mais rápido do que navegar por várias telas no console.
*   **Controle Granular:** A CLI frequentemente expõe todas as opções e parâmetros disponíveis em uma API da AWS, alguns dos quais podem não estar visíveis no console, permitindo um controle mais fino.
*   **Integração:** A CLI pode ser facilmente integrada a outras ferramentas de automação, pipelines de CI/CD e sistemas de monitoramento.
*   **Auditoria:** Comandos da CLI são registrados no AWS CloudTrail, fornecendo um rastro de auditoria de todas as ações realizadas.

### Como a CLI Funciona?

A AWS CLI é, na essência, um "invólucro" (wrapper) em Python para as **APIs REST** da AWS. Quando você executa um comando como `aws ec2 describe-vpcs`, a CLI:
1.  Formata seus parâmetros em uma requisição HTTP para o endpoint da API do serviço EC2.
2.  Assina digitalmente essa requisição com suas credenciais de segurança.
3.  Envia a requisição para a AWS.
4.  Recebe a resposta (geralmente em formato JSON).
5.  Formata a resposta e a exibe no seu terminal.

### Estrutura de um Comando da AWS CLI

A sintaxe é consistente e previsível:

`aws <serviço> <operação> [--parâmetros]`

*   `aws`: O programa executável da CLI.
*   `<serviço>`: O serviço da AWS com o qual você quer interagir (em minúsculas). Para VPC, o serviço é `ec2`.
    *   *Nota Histórica:* A VPC foi lançada como parte do serviço EC2. Por isso, todos os comandos para gerenciar componentes da VPC (sub-redes, tabelas de rotas, etc.) estão sob o comando `ec2`.
*   `<operação>`: A ação que você quer realizar. Os nomes das operações geralmente seguem um padrão `verbo-substantivo` (ex: `create-vpc`, `describe-vpcs`, `delete-vpc`).
*   `[--parâmetros]`: Os argumentos necessários para a operação (ex: `--cidr-block`, `--vpc-id`).

### Configuração e Autenticação

A CLI precisa saber "quem você é" para que a AWS possa verificar suas permissões. Ela procura por credenciais em uma ordem específica:

1.  **Variáveis de Ambiente:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, etc.
2.  **IAM Role (Melhor Prática para EC2):** Se a CLI estiver rodando em uma instância EC2 com uma IAM Role anexada, ela obterá credenciais temporárias automaticamente do serviço de metadados. Esta é a forma mais segura e recomendada para instâncias.
3.  **Arquivo de Credenciais (`~/.aws/credentials`):** O método mais comum para configurar a CLI em uma máquina de desenvolvedor ou administrador. O comando `aws configure` cria este arquivo para você, armazenando as chaves de um usuário IAM.

## 2. Comandos Essenciais via CLI (Prática - 30 min)

Neste laboratório, vamos usar a AWS CLI para realizar operações de "leitura" (describe), inspecionando os recursos da nossa `Lab-VPC` a partir da linha de comando. Isso simula um cenário de troubleshooting ou auditoria rápida.

### Cenário: Auditoria Rápida de Recursos da VPC

Um engenheiro de rede precisa rapidamente obter informações sobre os componentes de uma VPC específica para verificar uma configuração ou diagnosticar um problema. Em vez de navegar pelo console, ele usará a AWS CLI para extrair os dados necessários de forma eficiente.

### Roteiro Prático

**Passo 1: Conectar à Instância e Preparar o Ambiente**
1.  Conecte-se via SSH ao seu `WebServer-Lab` (lançado no Módulo 2.2). Ele já tem uma IAM Role com permissões de leitura para o S3. Vamos garantir que ele também tenha permissões para o EC2.
2.  **Adicionar Permissões:** Vá ao console do IAM, encontre a role anexada à sua instância (`EC2-S3-ReadOnly-Role` ou similar) e anexe a política gerenciada pela AWS chamada `AmazonEC2ReadOnlyAccess`. Isso permitirá que nossa instância descreva recursos da VPC.

**Passo 2: Descrever a VPC**
1.  Na sessão SSH do `WebServer-Lab`, vamos obter os detalhes da nossa `Lab-VPC` (criada no Módulo 3.1). Podemos listar todas as VPCs, mas isso pode ser muito verboso. Vamos filtrar pela tag de nome.
    ```bash
    aws ec2 describe-vpcs --filters "Name=tag:Name,Values=Essential-Custom-VPC"
    ```
2.  A saída é um grande bloco de JSON. Para extrair apenas o ID da VPC, podemos usar a flag `--query` com a sintaxe JMESPath e `--output text` para obter um valor limpo.
    ```bash
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=Essential-Custom-VPC" --query "Vpcs[0].VpcId" --output text)
    echo "O ID da nossa VPC é: $VPC_ID"
    ```

**Passo 3: Descrever as Sub-redes**
1.  Agora, vamos listar as sub-redes que pertencem à nossa `Lab-VPC`, usando a variável que acabamos de criar.
    ```bash
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"
    ```
2.  Vamos formatar a saída em uma tabela para melhor legibilidade e mostrar apenas os campos que nos interessam: o ID da sub-rede, seu bloco CIDR e sua tag de Nome.
    ```bash
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].{ID:SubnetId, CIDR:CidrBlock, Name:Tags[?Key==`Name`].Value | [0]}' --output table
    ```

**Passo 4: Descrever as Tabelas de Rotas**
1.  Vamos inspecionar as tabelas de rotas da nossa VPC e suas rotas.
    ```bash
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --output json
    ```
    Inspecione o JSON para ver as rotas (`Routes`) e as associações (`Associations`) para cada tabela. Tente identificar a tabela de rotas pública e a privada.

**Passo 5: Criar um Recurso (Exemplo: Tag)**
1.  A CLI também é usada para criar e modificar recursos. Vamos adicionar uma nova tag à nossa VPC para demonstrar uma operação de "escrita".
    ```bash
    aws ec2 create-tags --resources $VPC_ID --tags "Key=ManagedBy,Value=CLI"
    ```
2.  **Verificação:** Descreva a VPC novamente e você verá a nova tag na lista.
    ```bash
    aws ec2 describe-vpcs --vpc-ids $VPC_ID --query "Vpcs[0].Tags" --output table
    ```

Este laboratório oferece um vislumbre do poder e da flexibilidade da AWS CLI. Dominar a capacidade de consultar e manipular recursos a partir da linha de comando é uma habilidade essencial para passar da administração manual para a automação e a Infraestrutura como Código.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Use `--query` e `--output`:** Estas flags são suas melhores amigas para extrair informações específicas e formatar a saída da CLI. Use `--query` com JMESPath para filtrar e selecionar dados, e `--output text` para scripts ou `--output json` para processamento com `jq`.
*   **Filtros do Lado do Servidor:** Sempre que possível, use a flag `--filters` para reduzir a quantidade de dados retornados pela API. Isso acelera os comandos e reduz o tráfego de rede.
*   **Automação com Scripts:** A AWS CLI é a base para scripts de automação. Combine-a com Bash, Python ou PowerShell para criar fluxos de trabalho complexos e repetíveis.
*   **Princípio do Menor Privilégio:** Configure as credenciais da AWS CLI com o princípio do menor privilégio, concedendo apenas as permissões necessárias para as ações que você pretende executar.
*   **Documentação da CLI:** A documentação da AWS CLI é excelente. Use `aws <service> help` ou `aws <service> <operation> help` para obter informações detalhadas sobre comandos e parâmetros.
*   **Versionamento:** Mantenha seus scripts da AWS CLI sob controle de versão (Git) para rastrear alterações, colaborar com a equipe e reverter para versões anteriores, se necessário.
*   **Evite Credenciais Hardcoded:** Nunca armazene suas chaves de acesso diretamente em scripts. Use `aws configure`, variáveis de ambiente ou IAM Roles para gerenciar credenciais de forma segura.
