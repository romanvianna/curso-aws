# Módulo 2.1: Estratégia Multi-Contas (Multi-Account Strategy)

**Tempo de Aula:** 90 minutos de teoria, 90 minutos de prática

## Pré-requisitos

*   Conhecimento básico de AWS IAM (usuários, grupos, políticas).
*   Familiaridade com o console da AWS.
*   Compreensão dos conceitos de segurança e governança em ambientes de nuvem.

## Objetivos

*   Entender por que uma estratégia de múltiplas contas AWS é a melhor prática para governança, segurança, faturamento e isolamento em escala.
*   Aprender sobre o AWS Organizations como o serviço central para gerenciar um ambiente multi-contas de forma centralizada.
*   Analisar os componentes do AWS Organizations: Conta de Gerenciamento, Unidades Organizacionais (OUs), Contas-Membro e Políticas de Controle de Serviço (SCPs).
*   Projetar e implementar uma estrutura organizacional básica usando AWS Organizations, incluindo a criação de OUs e contas-membro.
*   Compreender o impacto das SCPs na segurança e conformidade em toda a organização.

---

## 1. O Paradigma de Múltiplas Contas (Teoria - 90 min)

### Por que não uma Única Conta Gigante?

Quando uma organização começa a usar a AWS, é comum começar com uma única conta. No entanto, à medida que a adoção cresce, com múltiplas equipes, projetos e ambientes (desenvolvimento, teste, produção), uma única conta se torna um grande gargalo e um risco significativo. Os problemas incluem:

*   **Segurança e Raio de Explosão (Blast Radius):** Uma conta AWS é a unidade fundamental de isolamento de segurança. Se as credenciais de um administrador com acesso total a uma única conta forem comprometidas, o invasor terá acesso a **todos** os recursos de **todos** os projetos e ambientes. O "raio de explosão" do incidente é máximo, podendo causar danos catastróficos.
*   **Governança e Limites de Recursos:** As contas da AWS têm cotas e limites de serviço (ex: número de VPCs por região, número de instâncias que podem ser lançadas). Em uma única conta, um projeto pode consumir todos os recursos disponíveis, impactando outros projetos ("o vizinho barulhento"). É difícil impor políticas de uso e consumo.
*   **Faturamento e Contabilidade:** Rastrear os custos de projetos ou equipes específicas em uma única conta é complexo e requer uma estratégia de tagueamento rigorosa e perfeita, o que raramente acontece. É difícil saber exatamente quanto o "Projeto X" está custando, dificultando a alocação de custos e a otimização.
*   **Autonomia da Equipe:** É difícil dar autonomia às equipes para inovar e experimentar se elas estão todas compartilhando o mesmo "playground", com medo de impactar os recursos de produção ou de outras equipes.
*   **Isolamento de Dados:** Misturar dados de diferentes ambientes ou projetos na mesma conta pode levar a riscos de conformidade e vazamento de dados.

### A Estratégia de Múltiplas Contas: A Melhor Prática

A melhor prática recomendada pela AWS é adotar uma **estratégia de múltiplas contas**. A ideia é usar contas diferentes para isolar cargas de trabalho, ambientes e equipes. Isso cria barreiras de segurança, simplifica a governança e melhora a agilidade.

*   **Isolamento de Ambientes:** Contas separadas para Desenvolvimento, Teste e Produção. Isso cria uma barreira de segurança forte; um erro no ambiente de desenvolvimento não pode, de forma alguma, impactar a produção.
*   **Isolamento por Unidade de Negócio/Projeto:** Contas separadas para diferentes equipes ou produtos. Isso simplifica o faturamento (cada conta tem sua própria fatura) e dá autonomia às equipes para gerenciar seus próprios recursos.
*   **Contas Dedicadas para Funções Específicas:** Contas dedicadas para funções de toda a organização, como segurança (logs, ferramentas de auditoria), rede (Transit Gateways, endpoints) e serviços compartilhados (Active Directory, ferramentas de CI/CD).

### AWS Organizations: O Gerenciador Central

Gerenciar dezenas ou centenas de contas individualmente seria impossível. O **AWS Organizations** é o serviço que permite **governar e gerenciar centralmente seu ambiente de múltiplas contas**.

*   **Como Funciona:** Você designa uma conta para ser a **conta de gerenciamento (management account)**. A partir desta conta, você pode:
    *   Criar novas contas AWS de forma programática.
    *   Convidar contas existentes para se juntarem à sua organização.
    *   Agrupar contas em **Unidades Organizacionais (OUs)** para aplicar políticas em grupos de contas.
    *   Aplicar políticas de governança a toda a organização, a uma OU ou a contas individuais.
    *   Centralizar o faturamento (Consolidated Billing), recebendo uma única fatura para todas as contas.

### Componentes do AWS Organizations

1.  **Conta de Gerenciamento (Management Account):** O topo da hierarquia. Esta conta é usada para gerenciar a organização e pagar a fatura de todas as contas-membro. Deve ser usada **apenas** para tarefas de gerenciamento da organização, não para hospedar cargas de trabalho, para minimizar seu risco de comprometimento.

2.  **Unidades Organizacionais (OUs):** São contêineres para agrupar contas. Você pode criar uma hierarquia de OUs que espelhe a estrutura da sua empresa, facilitando a aplicação de políticas e a delegação de administração. Por exemplo:
    *   `Root`
        *   `OU: Infrastructure` (contas de segurança, rede, auditoria)
        *   `OU: Workloads`
            *   `OU: Production`
                *   `Conta: App-A-Prod`
                *   `Conta: App-B-Prod`
            *   `OU: Development`
                *   `Conta: App-A-Dev`
                *   `Conta: App-B-Dev`

3.  **Políticas de Controle de Serviço (SCPs - Service Control Policies):**
    *   Esta é a ferramenta de governança mais poderosa do Organizations. Uma SCP é um tipo de política que especifica os **serviços e ações da AWS que os usuários e roles podem usar** nas contas afetadas. 
    *   **Importante:** SCPs **não concedem** permissões. Elas atuam como um **filtro** ou uma **guarda de proteção**. As permissões ainda são concedidas via políticas IAM nas contas individuais. No entanto, se uma permissão for negada por uma SCP no nível da OU, um administrador na conta-membro não poderá usá-la, mesmo que ele tenha uma política IAM de `AdministratorAccess`. SCPs são usadas para estabelecer "guardrails" de segurança e conformidade.
    *   **Caso de Uso:** Você pode criar uma SCP que nega o acesso a serviços que sua empresa não usa (ex: serviços de machine learning exóticos) ou que nega ações perigosas (ex: `iam:DeleteRole`) em contas de produção. Você pode garantir que certos serviços só possam ser usados em certas regiões, para fins de conformidade de dados (ex: `Deny` todas as ações em `eu-west-1` se seus dados devem permanecer na `us-east-1`).

## 2. Implementação de uma Arquitetura Multi-Conta (Prática - 90 min)

Neste laboratório, vamos usar nossa conta atual como a conta de gerenciamento para criar uma nova organização, estruturar OUs e criar uma nova conta-membro de forma programática. Isso simula o processo de onboarding de novas equipes ou projetos em um ambiente corporativo.

### Cenário: Estrutura Organizacional para uma Empresa de Software

Uma empresa de software em crescimento deseja organizar suas contas AWS para isolar ambientes e equipes. Eles precisam de uma estrutura que permita a criação de contas de desenvolvimento e produção, e que possa impor políticas de segurança em nível organizacional. Vamos criar uma estrutura básica com OUs para infraestrutura e cargas de trabalho (produção e desenvolvimento), e depois criar uma nova conta para um ambiente de sandbox.

### Roteiro Prático

**Passo 1: Criar a Organização**
1.  Faça login na sua conta AWS. Esta se tornará sua conta de gerenciamento.
2.  Navegue até o console do **AWS Organizations**.
3.  Se for a primeira vez, você verá uma tela de boas-vindas. Clique em **"Create an organization"**.
4.  A organização será criada, e sua conta atual se tornará a conta de gerenciamento, listada na OU Raiz (`Root`).

**Passo 2: Criar a Estrutura de Unidades Organizacionais (OUs)**
1.  Selecione a **Raiz (Root)** na hierarquia.
2.  No lado direito, clique em **Actions > Create new** na seção de Unidades Organizacionais.
3.  Crie a primeira OU de nível superior:
    *   **Name:** `Infrastructure` (para contas como Security, Network, Shared Services)
4.  Crie a segunda OU de nível superior:
    *   **Name:** `Workloads` (para contas de aplicação, divididas por ambiente)
5.  Agora, clique na OU `Workloads` para navegar até ela.
6.  Crie duas OUs aninhadas dentro de `Workloads`:
    *   `Production`
    *   `Development`
7.  Sua hierarquia agora deve se parecer com:
    *   `Root`
        *   `OU: Infrastructure`
        *   `OU: Workloads`
            *   `OU: Production`
            *   `OU: Development`

**Passo 3: Criar uma Nova Conta-Membro**
1.  Navegue de volta para a visão principal de **AWS accounts**.
2.  Clique em **"Add an AWS account"**.
3.  Selecione **"Create an AWS account"**.
4.  Preencha os detalhes:
    *   **AWS account name:** `Sandbox-Account`
    *   **Email address for the root user:** **Use um endereço de e-mail que você controla e que ainda não esteja associado a uma conta AWS**. Você pode usar um alias de e-mail (ex: `seuemail+sandbox@gmail.com`) ou um serviço de e-mail temporário para testes.
    *   **IAM role name:** Deixe o padrão (`OrganizationAccountAccessRole`). Isso cria uma role na nova conta que permite que administradores da conta de gerenciamento acessem a conta-membro.
5.  Clique em **"Create AWS account"**. O processo pode levar alguns minutos. A nova conta aparecerá na OU Raiz inicialmente.

**Passo 4: Mover a Nova Conta para uma OU**
1.  Quando a nova conta aparecer na lista (fora de qualquer OU), marque a caixa de seleção ao lado dela.
2.  Clique em **Actions > Move**.
3.  Selecione a OU `Development` (dentro de `Workloads`) e clique em **"Move AWS account"**.

**Passo 5: Aplicar uma Política de Controle de Serviço (SCP)**
Vamos criar uma SCP que impede que contas de desenvolvimento usem o Amazon SageMaker, um serviço caro de ML, como um exemplo de guardrail de custo/segurança.
1.  No menu à esquerda, vá para **Policies > Service control policies**.
2.  Clique em **"Create policy"**.
3.  **Policy name:** `Deny-SageMaker-Access`
4.  Na seção de declaração da política, use o editor JSON ou o construtor de políticas para criar uma política que **Nega (`Deny`)** todas as ações (`*`) para o serviço **SageMaker** (`sagemaker:*`).
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Deny",
                "Action": "sagemaker:*",
                "Resource": "*"
            }
        ]
    }
    ```
5.  Crie a política.
6.  **Anexar a SCP:**
    *   Selecione a política recém-criada.
    *   Clique em **Actions > Attach**.
    *   Selecione a OU `Development` na hierarquia e clique em **"Attach policy"**.

**Passo 6: Validar (Acessando a Nova Conta)**
1.  Verifique o e-mail que você usou para criar a `Sandbox-Account` para redefinir a senha do usuário root e fazer o primeiro login.
2.  Faça login na `Sandbox-Account` como usuário root.
3.  Tente navegar até o console do **Amazon SageMaker** ou tente executar um comando da CLI do SageMaker (ex: `aws sagemaker list-notebook-instances`). Você receberá uma mensagem de acesso negado (`AccessDeniedException`), mesmo sendo o usuário root. Isso acontece porque a SCP aplicada à OU `Development` tem precedência e nega o acesso no nível da organização, independentemente das permissões IAM dentro da conta.

Este laboratório demonstra como o AWS Organizations fornece as ferramentas para construir uma estrutura de nuvem bem governada, segura e escalável, que é a base para qualquer implantação empresarial na AWS.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Conta de Gerenciamento Segura:** Mantenha a conta de gerenciamento o mais segura possível. Use MFA forte para o usuário root e limite o acesso a esta conta apenas para tarefas de gerenciamento do Organizations e faturamento.
*   **Estrutura de OUs Lógica:** Projete sua hierarquia de OUs para refletir a estrutura da sua organização, seus requisitos de segurança e conformidade. Isso facilita a aplicação de SCPs e a delegação de administração.
*   **SCPs como Guardrails:** Use SCPs para definir "guardrails" de segurança e conformidade em nível organizacional. Elas são uma ferramenta poderosa para impor políticas de forma centralizada e garantir que as contas-membro operem dentro dos limites definidos.
*   **Princípio do Menor Privilégio com SCPs:** SCPs devem ser usadas para negar ações que não são permitidas. As permissões são concedidas por políticas IAM dentro das contas-membro.
*   **Automação da Criação de Contas:** Automatize a criação de novas contas e sua movimentação para as OUs corretas usando a API do Organizations ou ferramentas como AWS Control Tower.
*   **Centralização de Logs e Auditoria:** Configure o CloudTrail na conta de gerenciamento para agregar logs de todas as contas-membro, fornecendo uma trilha de auditoria centralizada.
*   **Faturamento Consolidado:** Aproveite o faturamento consolidado para simplificar a gestão de custos e potencialmente obter descontos por volume.
*   **Delegated Administrator:** Para serviços como AWS Config, CloudTrail, GuardDuty, você pode delegar a administração para uma conta-membro específica (geralmente uma conta de segurança), em vez de gerenciar tudo a partir da conta de gerenciamento.