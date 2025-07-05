# Módulo 2.2: Controle Granular de Acesso com IAM

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Pré-requisitos

*   Conhecimento básico de AWS IAM (usuários, grupos, roles, políticas).
*   Familiaridade com o conceito de tags na AWS.
*   Compreensão de como as permissões são avaliadas no IAM.

## Objetivos

*   Entender o **Controle de Acesso Baseado em Atributos (ABAC)** como um modelo de permissões escalável e flexível.
*   Aprender a usar tags como atributos para implementar o ABAC no IAM.
*   Criar políticas IAM customizadas que usam condições para restringir ações de gerenciamento da VPC e outros recursos com base em tags.
*   Criar e testar uma role que concede permissões limitadas a um "desenvolvedor de projeto", demonstrando a escalabilidade do ABAC.
*   Discutir cenários de aplicação do ABAC em ambientes corporativos complexos.

---

## 1. Modelos de Permissão: RBAC vs. ABAC (Teoria - 45 min)

Gerenciar permissões em uma organização em crescimento é um desafio. Tradicionalmente, muitas organizações usam um modelo chamado **RBAC (Role-Based Access Control)**.

*   **RBAC (Controle de Acesso Baseado em Função):**
    *   **Conceito:** Você cria "roles" (funções) que correspondem a cargos na empresa (ex: `NetworkAdmin`, `Developer`, `Auditor`). Você então atribui usuários a essas roles.
    *   **Desafios:** À medida que o número de projetos, equipes e ambientes cresce, você acaba com uma explosão de roles (`ProjectA-Developer`, `ProjectB-Developer`, `ProjectA-NetworkAdmin`, `Prod-NetworkAdmin`, `Dev-NetworkAdmin`), o que se torna difícil de gerenciar, manter e auditar. A granularidade é limitada pela quantidade de roles que você está disposto a criar.

Uma abordagem mais moderna e escalável é o **ABAC (Attribute-Based Access Control)**.

*   **ABAC (Controle de Acesso Baseado em Atributos):**
    *   **Conceito:** Em vez de definir permissões com base na função de um usuário, o ABAC concede acesso com base nos **atributos** da identidade (quem está fazendo a requisição), do recurso (o que está sendo acessado) e do ambiente (de onde a requisição vem, horário, etc.).
    *   **Flexibilidade:** A política de permissão se torna uma pergunta mais geral e dinâmica: "Permitir que um usuário com o atributo `Project: Blue` realize a ação `ec2:CreateSubnet` em um recurso com o atributo `Project: Blue`?"
    *   **Escalabilidade:** Permite criar um número pequeno de políticas e roles genéricas que escalam para toda a organização, independentemente do número de projetos ou equipes.

Na AWS, a maneira mais comum de implementar o ABAC é usando **tags**. As tags são pares de chave-valor que você pode anexar aos seus recursos do IAM (usuários, roles) e aos seus recursos da AWS (instâncias EC2, VPCs, sub-redes, S3 buckets, etc.).

### Implementando ABAC com Tags no IAM

O IAM permite que você use **condições** em suas políticas para verificar a presença ou o valor de tags. Isso permite criar um número pequeno de políticas e roles genéricas que escalam para toda a organização.

**Chaves de Condição Essenciais para ABAC:**

1.  `aws:PrincipalTag/<tag-key>`:
    *   Verifica a tag anexada à **identidade** (usuário ou role) que está fazendo a requisição.
    *   *Exemplo:* `"Condition": {"StringEquals": {"aws:PrincipalTag/project": "blue"}}` - Garante que a identidade tem a tag `project` com o valor `blue`.

2.  `ec2:ResourceTag/<tag-key>`:
    *   Verifica a tag em um **recurso existente** que está sendo modificado ou descrito.
    *   *Exemplo:* Permitir `ec2:DeleteVpc` somente se a VPC tiver a tag `project: blue` - Garante que a ação só pode ser realizada em recursos com a tag `project: blue`.

3.  `aws:RequestTag/<tag-key>`:
    *   Verifica a tag que está sendo aplicada a um recurso **durante sua criação**. Isso é crucial para garantir que os usuários não possam criar recursos sem as tags corretas, contornando assim as políticas de permissão.
    *   *Exemplo:* Permitir `ec2:CreateVpc` somente se a requisição incluir uma tag `project: blue` - Força a marcação de recursos na criação.

**Exemplo de Política ABAC (Conceitual):**

Imagine uma única role `Developer-Role` para todos os desenvolvedores. A política anexada a ela poderia dizer:

*   **Statement 1:** Permitir `ec2:RunInstances` se `aws:RequestTag/project` for igual a `aws:PrincipalTag/project`. (Um desenvolvedor com a tag `project: blue` só pode lançar instâncias se ele as marcar com `project: blue`).
*   **Statement 2:** Permitir `ec2:StopInstances` se `ec2:ResourceTag/project` for igual a `aws:PrincipalTag/project`. (Um desenvolvedor com a tag `project: blue` só pode parar instâncias que já estão marcadas com `project: blue`).

Com esta única role, você pode gerenciar centenas de projetos. Para dar a um desenvolvedor acesso a um novo projeto, você simplesmente atualiza a tag `project` em seu usuário IAM. Isso reduz a complexidade de gerenciamento de permissões e aumenta a agilidade.

---

## 2. Criação de Roles e Políticas Customizadas (Prática - 75 min)

Neste laboratório, vamos criar uma role IAM para um "Desenvolvedor do Projeto Hélio". Este desenvolvedor só poderá iniciar e parar instâncias EC2 que pertençam ao seu projeto, identificado pela tag `Project: Helio`. Isso simula um ambiente corporativo onde diferentes equipes gerenciam seus próprios recursos, mas de forma centralizada e controlada.

### Cenário: Gerenciamento de Instâncias por Projeto

Uma grande empresa de tecnologia tem várias equipes de desenvolvimento, cada uma trabalhando em projetos diferentes. Cada equipe é responsável por gerenciar suas próprias instâncias EC2. O desafio é garantir que um desenvolvedor de um projeto não possa acidentalmente (ou intencionalmente) parar ou modificar instâncias pertencentes a outro projeto. Usaremos ABAC para impor essa segregação.

### Roteiro Prático

**Passo 1: Preparar as Instâncias (Adicionar Tags)**
1.  Navegue até o console do **EC2**.
2.  Selecione duas das suas instâncias de laboratório (ou crie duas novas).
3.  Vá para a aba **"Tags"** e clique em **"Manage tags"**.
4.  Adicione as seguintes tags:
    *   Para a primeira instância: `Key: Project`, `Value: Helio`.
    *   Para a segunda instância: `Key: Project`, `Value: Artemis`.
5.  Salve as tags.

**Passo 2: Criar a Política IAM Customizada (ABAC)**
1.  Navegue até o console do **IAM** > **Policies** > **Create policy**.
2.  Selecione a aba **JSON**.
3.  Cole a seguinte política. Ela permite iniciar/parar instâncias, mas apenas se a tag `Project` do recurso corresponder à tag `Project` do principal (o usuário/role que faz a chamada).

    ```json
    {
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
    ```
    *   **Analisando a Condição:** `"ec2:ResourceTag/Project": "${aws:PrincipalTag/Project}"` é o coração do ABAC. Ela compara dinamicamente a tag do recurso (`ec2:ResourceTag/Project`) com a tag do principal (`aws:PrincipalTag/Project`). Isso significa que a permissão só é concedida se os valores das tags forem idênticos.

4.  **Policy Name:** `Developer-Project-Access-Policy`
5.  Clique em **"Create policy"**.

**Passo 3: Criar a Role e Anexar a Política e as Tags**
1.  No IAM, vá para **Roles** > **Create role**.
2.  **Trusted entity type:** `AWS account`, selecione **"This account"** (para permitir que usuários da sua conta assumam esta role).
3.  Clique em **"Next"**. Anexe a `Developer-Project-Access-Policy`.
4.  Clique em **"Next"**.
5.  **Role name:** `Developer-Role-Helio` (Nomeie a role de forma descritiva).
6.  **Adicionar Tags à Role:** Na mesma página, na seção de tags, adicione a tag que define o projeto desta role. Esta tag será usada pela condição na política:
    *   `Key: Project`, `Value: Helio`
7.  Clique em **"Create role"**.

**Passo 4: Testar a Role**
1.  Use o recurso **"Switch role"** no console da AWS para assumir a `Developer-Role-Helio`. (Você precisará do Account ID e do nome da role).

**Passo 5: Validar as Permissões**
Agora você está operando com as permissões da `Developer-Role-Helio`, que tem a tag `Project: Helio`.
1.  Navegue até o console do **EC2**.
2.  Você deve conseguir ver a lista de instâncias (devido à permissão `DescribeInstances`).
3.  **Teste 1 (Sucesso):**
    *   Selecione a instância com a tag `Project: Helio`.
    *   Vá em **Instance state > Stop instance**. A ação deve ser **bem-sucedida**. A condição da política (`Helio == Helio`) foi satisfeita.
4.  **Teste 2 (Falha):**
    *   Selecione a instância com a tag `Project: Artemis`.
    *   Vá em **Instance state > Stop instance**. A ação deve **falhar** com um erro de autorização. A condição da política (`Artemis == Helio`) não foi satisfeita, pois as tags não correspondem.
5.  **Teste 3 (Escalabilidade - Discussão):**
    *   Para dar acesso a um desenvolvedor a um novo projeto (ex: `Project: Jupiter`), você não precisa criar uma nova política ou role. Basta criar uma nova role (ex: `Developer-Role-Jupiter`) e anexar a mesma `Developer-Project-Access-Policy`, mas com a tag `Project: Jupiter` na role. Isso demonstra a escalabilidade do ABAC.

Este laboratório demonstra o poder do ABAC. Com uma única política e role, você pode gerenciar o acesso a múltiplos projetos simplesmente alterando uma tag, em vez de criar e gerenciar dezenas de políticas diferentes. Isso simplifica a governança e a automação de permissões em larga escala.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Defina uma Estratégia de Tagging:** Antes de implementar o ABAC, defina uma estratégia clara de tagging para seus recursos e identidades. Consistência é fundamental para o ABAC funcionar corretamente.
*   **Comece Pequeno:** Comece aplicando o ABAC a um subconjunto de recursos ou ações e expanda gradualmente.
*   **Teste Exaustivamente:** Teste suas políticas ABAC rigorosamente para garantir que elas concedam as permissões corretas e neguem as incorretas.
*   **Use `aws:RequestTag` para Forçar Tagging:** Utilize a condição `aws:RequestTag` em políticas de controle de serviço (SCPs) ou políticas de permissão para garantir que novos recursos sejam criados com as tags obrigatórias. Isso é crucial para a governança e para que o ABAC funcione de ponta a ponta.
*   **Evite `*` em `Resource` com ABAC:** Sempre que possível, evite usar `"Resource": "*"` em conjunto com ABAC, a menos que você esteja muito confiante de que suas condições de tag são robustas o suficiente para restringir o acesso. Prefira especificar os ARNs dos recursos.
*   **Auditoria com CloudTrail:** Monitore as ações do IAM e as tentativas de acesso negadas no CloudTrail para identificar falhas de configuração ou tentativas de acesso não autorizado.
*   **Combine com RBAC:** O ABAC não substitui completamente o RBAC. Em muitos casos, uma combinação de ambos pode ser a abordagem mais eficaz. Use RBAC para funções amplas (ex: `Admin`, `ReadOnly`) e ABAC para granularidade dentro dessas funções (ex: `Developer` pode gerenciar apenas recursos com a tag do seu projeto).
