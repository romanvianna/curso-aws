# Módulo 3.3: Conformidade e Auditoria

**Tempo de Aula:** 60 minutos de teoria, 120 minutos de prática

## Objetivos

- Entender o conceito de governança e auditoria contínua na nuvem.
- Aprender como o AWS Config monitora e avalia continuamente a configuração dos seus recursos.
- Utilizar regras do AWS Config (gerenciadas e customizadas) para detectar configurações fora de conformidade.
- Implementar a remediação automática de configurações não conformes usando o AWS Config.

---

## 1. Governança e Auditoria Contínua (Teoria - 60 min)

**Governança na nuvem** é o processo de definir e aplicar políticas para controlar custos, minimizar riscos de segurança e garantir a conformidade com padrões externos (como PCI DSS, HIPAA) e internos. A auditoria tradicional, realizada em intervalos (ex: trimestralmente), não é eficaz em um ambiente de nuvem dinâmico onde a infraestrutura pode mudar a cada minuto.

Isso leva à necessidade de **auditoria contínua**, um processo automatizado que monitora e avalia constantemente o ambiente em relação a um conjunto de políticas definidas.

### AWS Config: O Auditor Contínuo da sua Infraestrutura

O **AWS Config** é o principal serviço da AWS para governança e auditoria contínua. Sua função é monitorar e registrar continuamente as **configurações dos seus recursos da AWS** e avaliar essas configurações em relação a regras desejadas.

**Como o AWS Config Funciona?**

1.  **Inventário e Histórico de Configuração:**
    -   Quando você habilita o Config, ele descobre os recursos suportados na sua conta e cria um **Item de Configuração (Configuration Item - CI)** para cada um. Um CI é um snapshot em um ponto no tempo da configuração de um recurso (ex: as regras de um Security Group, as tags de uma instância, a configuração de uma VPC).
    -   O Config então monitora continuamente esses recursos. Sempre que uma configuração **muda**, ele grava um novo CI. Isso lhe dá um **histórico completo de cada alteração** feita em cada recurso ao longo do tempo. Você pode responder a perguntas como: "Quais eram as regras deste Security Group na terça-feira passada às 14h?"

2.  **Regras do AWS Config (Config Rules):**
    -   O verdadeiro poder do Config está nas **regras**. Uma regra do Config representa a sua configuração **desejada** para um recurso. O Config avalia continuamente as configurações dos seus recursos em relação às regras que você define.
    -   Se um recurso viola uma regra, o Config o marca como **NÃO CONFORME (NON_COMPLIANT)** e gera um resultado.
    -   **Tipos de Regras:**
        -   **Regras Gerenciadas pela AWS:** A AWS fornece uma biblioteca com mais de 100 regras pré-construídas para as melhores práticas mais comuns (ex: `sg-ssh-disabled`, `s3-bucket-public-read-prohibited`, `encrypted-volumes`).
        -   **Regras Customizadas:** Você pode escrever suas próprias regras usando funções Lambda ou Guard (uma linguagem de política da AWS) para verificar condições de configuração muito específicas da sua organização.

3.  **Remediação Automática:**
    -   Detectar um problema é bom, mas consertá-lo automaticamente é melhor. O Config permite que você configure **Ações de Remediação** que são acionadas quando um recurso se torna não conforme.
    -   Uma ação de remediação é tipicamente um **documento do AWS Systems Manager (SSM) Automation**. A AWS fornece documentos pré-construídos para muitas ações de remediação comuns (ex: um documento que remove a regra de entrada ofensiva de um Security Group).

### AWS Config vs. CloudTrail

-   **CloudTrail:** Responde "**Quem** fez a chamada de API para mudar X?"
-   **AWS Config:** Responde "Qual era a **configuração** de X antes e depois da mudança, e essa nova configuração está em **conformidade** com minhas políticas?"

Eles são complementares. O CloudTrail registra o evento da mudança, e o Config registra o resultado da mudança no estado do recurso.

### Pacotes de Conformidade (Conformance Packs)

Um pacote de conformidade é uma coleção de regras do AWS Config e ações de remediação que podem ser facilmente implantadas como um único pacote em sua conta ou organização. Eles são projetados para ajudá-lo a configurar rapidamente os controles necessários para frameworks de conformidade como PCI DSS, HIPAA ou o AWS Well-Architected Framework.

---

## 2. Implementação de Conformidade Automatizada (Prática - 120 min)

Neste laboratório, vamos usar o AWS Config para detectar uma configuração de segurança incorreta e, em seguida, configurar uma ação para remediá-la automaticamente.

### Cenário

-   **Política:** Nenhum Security Group deve permitir tráfego de entrada SSH (porta 22) de `0.0.0.0/0`.
-   **Detecção:** Usaremos uma regra gerenciada do AWS Config para detectar violações desta política.
-   **Remediação:** Se uma violação for detectada, usaremos uma ação de remediação automática para remover a regra ofensiva.

### Roteiro Prático

**Passo 1: Configurar o AWS Config**
1.  Navegue até o console do **AWS Config**.
2.  Se for a primeira vez, clique em **"Get started"**.
3.  **Settings:**
    -   **Resource types to record:** Selecione **"Record all resources supported in this region"**.
    -   **AWS Config role:** Permita que o Config crie a role necessária.
    -   **Amazon S3 bucket:** Permita que o Config crie um novo bucket para armazenar o histórico de configuração.
4.  Pule a seção de regras por enquanto e salve a configuração.

**Passo 2: Adicionar a Regra de Detecção**
1.  No menu do Config, vá para **Rules > Add rule**.
2.  Na caixa de busca, digite `ssh` e selecione a regra gerenciada `restricted-ssh`.
3.  **Trigger:** A regra será acionada por mudanças de configuração.
4.  Não há parâmetros para esta regra. Clique em **"Save"**.
5.  O Config começará a avaliar todos os seus Security Groups em relação a esta regra.

**Passo 3: Violar a Política Intencionalmente**
1.  Vá para o console da **VPC > Security Groups**.
2.  Crie um novo Security Group chamado `Non-Compliant-SG`.
3.  Adicione uma regra de entrada: `Type: SSH (22)`, `Source: Anywhere-IPv4 (0.0.0.0/0)`.

**Passo 4: Observar a Detecção**
1.  Volte para o console do **AWS Config > Rules**.
2.  Após alguns minutos, a regra `restricted-ssh` mostrará `1 noncompliant resource`.
3.  Clique na regra para ver os detalhes. Você verá o `Non-Compliant-SG` listado como o recurso que violou a política.

**Passo 5: Configurar a Remediação Automática**
1.  Selecione a regra `restricted-ssh`.
2.  No menu **Actions**, clique em **"Manage remediation"**.
3.  **Remediation method:** `Automatic remediation`.
4.  **Remediation action:** Escolha a ação `AWS-DisablePublicAccessForSecurityGroup`.
5.  **Resource ID parameter:** `GroupId` (o Config passará o ID do SG não conforme para a ação).
6.  **Parameters:**
    -   `IpProtocol`: `tcp`
    -   `FromPort`: `22`
    -   `ToPort`: `22`
    -   `CidrIp`: `0.0.0.0/0`
7.  Salve as alterações. O Config agora precisa de permissões para executar esta remediação. Ele pode solicitar a criação de uma nova IAM Role. Autorize.

**Passo 6: Testar a Remediação Automática**
1.  Para acionar a remediação novamente, vá para o `Non-Compliant-SG` e remova a regra SSH. Depois, adicione-a novamente. Isso cria um novo evento de mudança de configuração.
2.  Volte para o **AWS Config** e observe a regra. Ela se tornará não conforme novamente.
3.  Aguarde alguns minutos.
4.  Vá para a aba **"Remediation exception"** da regra. Você verá o status da ação de remediação mudar para `Action executed successfully`.
5.  **Validação Final:** Volte para o console da **VPC > Security Groups** e inspecione as regras de entrada do `Non-Compliant-SG`. A regra ofensiva que permitia SSH de `0.0.0.0/0` terá sido **removida automaticamente**.

Este laboratório demonstra o ciclo completo da governança na nuvem: definir uma política (a regra), detectar continuamente as violações e remediá-las automaticamente, garantindo que seu ambiente permaneça em um estado de conformidade conhecido e seguro.
