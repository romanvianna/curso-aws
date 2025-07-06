# Módulo 3.3: Conformidade e Auditoria

**Tempo de Aula:** 60 minutos de teoria, 120 minutos de prática

## Pré-requisitos

*   Conhecimento básico de segurança em nuvem e gerenciamento de recursos AWS.
*   Familiaridade com o console da AWS e o serviço IAM.
*   Compreensão dos conceitos de governança e auditoria em TI.

## Objetivos

*   Entender o conceito de governança e auditoria contínua na nuvem e sua importância em ambientes dinâmicos.
*   Aprender como o AWS Config monitora e avalia continuamente a configuração dos seus recursos AWS.
*   Utilizar regras do AWS Config (gerenciadas e customizadas) para detectar configurações fora de conformidade com políticas de segurança e melhores práticas.
*   Implementar a remediação automática de configurações não conformes usando o AWS Config e o AWS Systems Manager Automation.
*   Discutir o papel do AWS Config em frameworks de conformidade (PCI DSS, HIPAA, GDPR) e auditorias.

---

## 1. Governança e Auditoria Contínua (Teoria - 60 min)

**Governança na nuvem** é o processo de definir e aplicar políticas para controlar custos, minimizar riscos de segurança e garantir a conformidade com padrões externos (como PCI DSS, HIPAA, GDPR, LGPD) e internos. A auditoria tradicional, realizada em intervalos (ex: trimestralmente), não é eficaz em um ambiente de nuvem dinâmico onde a infraestrutura pode mudar a cada minuto.

Isso leva à necessidade de **auditoria contínua**, um processo automatizado que monitora e avalia constantemente o ambiente em relação a um conjunto de políticas definidas. O objetivo é identificar desvios de configuração (drift) e não conformidades em tempo real.

### AWS Config: O Auditor Contínuo da sua Infraestrutura

O **AWS Config** é o principal serviço da AWS para governança e auditoria contínua. Sua função é monitorar e registrar continuamente as **configurações dos seus recursos da AWS** e avaliar essas configurações em relação a regras desejadas.

**Como o AWS Config Funciona?**

1.  **Inventário e Histórico de Configuração:**
    *   Quando você habilita o Config, ele descobre os recursos suportados na sua conta e cria um **Item de Configuração (Configuration Item - CI)** para cada um. Um CI é um snapshot em um ponto no tempo da configuração de um recurso (ex: as regras de um Security Group, as tags de uma instância, a configuração de uma VPC).
    *   O Config então monitora continuamente esses recursos. Sempre que uma configuração **muda**, ele grava um novo CI. Isso lhe dá um **histórico completo de cada alteração** feita em cada recurso ao longo do tempo. Você pode responder a perguntas como: "Quais eram as regras deste Security Group na terça-feira passada às 14h?" ou "Quem alterou a configuração deste bucket S3?"

2.  **Regras do AWS Config (Config Rules):**
    *   O verdadeiro poder do Config está nas **regras**. Uma regra do Config representa a sua configuração **desejada** para um recurso. O Config avalia continuamente as configurações dos seus recursos em relação às regras que você define.
    *   Se um recurso viola uma regra, o Config o marca como **NÃO CONFORME (NON_COMPLIANT)** e gera um resultado.
    *   **Tipos de Regras:**
        *   **Regras Gerenciadas pela AWS:** A AWS fornece uma biblioteca com mais de 100 regras pré-construídas para as melhores práticas mais comuns (ex: `sg-ssh-disabled` para detectar SGs que permitem SSH de 0.0.0.0/0, `s3-bucket-public-read-prohibited` para buckets S3 públicos, `encrypted-volumes` para volumes EBS não criptografados).
        *   **Regras Customizadas:** Você pode escrever suas próprias regras usando funções Lambda (para lógica complexa) ou Guard (uma linguagem de política da AWS) para verificar condições de configuração muito específicas da sua organização que não são cobertas pelas regras gerenciadas.

3.  **Remediação Automática:**
    *   Detectar um problema é bom, mas consertá-lo automaticamente é melhor. O Config permite que você configure **Ações de Remediação** que são acionadas quando um recurso se torna não conforme.
    *   Uma ação de remediação é tipicamente um **documento do AWS Systems Manager (SSM) Automation**. A AWS fornece documentos pré-construídos para muitas ações de remediação comuns (ex: um documento que remove a regra de entrada ofensiva de um Security Group, ou que criptografa um volume EBS).

### AWS Config vs. CloudTrail

É comum confundir AWS Config e CloudTrail, mas eles são complementares:

*   **CloudTrail:** Responde "**Quem** fez a chamada de API para mudar X?" (Registra eventos de API).
*   **AWS Config:** Responde "Qual era a **configuração** de X antes e depois da mudança, e essa nova configuração está em **conformidade** com minhas políticas?" (Registra o estado da configuração do recurso).

Eles trabalham juntos para fornecer uma trilha de auditoria completa e um histórico de conformidade.

### Pacotes de Conformidade (Conformance Packs)

Um pacote de conformidade é uma coleção de regras do AWS Config e ações de remediação que podem ser facilmente implantadas como um único pacote em sua conta ou organização. Eles são projetados para ajudá-lo a configurar rapidamente os controles necessários para frameworks de conformidade como PCI DSS, HIPAA ou o AWS Well-Architected Framework, acelerando a adoção de padrões de segurança.

## 2. Implementação de Conformidade Automatizada (Prática - 120 min)

Neste laboratório, vamos usar o AWS Config para detectar uma configuração de segurança incorreta e, em seguida, configurar uma ação para remediá-la automaticamente. Isso simula um cenário de aplicação de políticas de segurança em tempo real.

### Cenário: Impondo a Política de Acesso SSH Restrito

Uma empresa tem uma política de segurança rigorosa que proíbe Security Groups de permitir acesso SSH (porta 22) de `0.0.0.0/0` (qualquer IP). Eles querem automatizar a detecção e a remediação de qualquer SG que viole essa política, garantindo que o ambiente permaneça seguro.

### Roteiro Prático

**Passo 1: Configurar o AWS Config**
1.  Navegue até o console do **AWS Config**.
2.  Se for a primeira vez, clique em **"Get started"**.
3.  **Settings:**
    *   **Resource types to record:** Selecione **"Record all resources supported in this region"** (para monitorar todos os tipos de recursos).
    *   **AWS Config role:** Permita que o Config crie a role necessária (`aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig`).
    *   **Amazon S3 bucket:** Permita que o Config crie um novo bucket para armazenar o histórico de configuração e os logs de entrega.
4.  Pule a seção de regras por enquanto e salve a configuração. O Config começará a registrar o histórico de configuração dos seus recursos.

**Passo 2: Adicionar a Regra de Detecção (`restricted-ssh`)**
1.  No menu do Config, vá para **Rules > Add rule**.
2.  Na caixa de busca, digite `ssh` e selecione a regra gerenciada `restricted-ssh`.
3.  **Trigger:** A regra será acionada por mudanças de configuração (`Configuration changes`).
4.  Não há parâmetros para esta regra. Clique em **"Save"**.
5.  O Config começará a avaliar todos os seus Security Groups em relação a esta regra. Inicialmente, pode levar alguns minutos para a avaliação inicial.

**Passo 3: Violar a Política Intencionalmente**
1.  Vá para o console da **VPC > Security Groups**.
2.  Crie um novo Security Group chamado `Non-Compliant-SG`.
3.  Adicione uma regra de entrada:
    *   **Type:** `SSH (22)`
    *   **Source:** `Anywhere-IPv4 (0.0.0.0/0)`
    *   **Description:** `Regra de teste para violar a política`

**Passo 4: Observar a Detecção**
1.  Volte para o console do **AWS Config > Rules**.
2.  Após alguns minutos (o tempo de avaliação do Config), a regra `restricted-ssh` mostrará `1 noncompliant resource`.
3.  Clique na regra para ver os detalhes. Você verá o `Non-Compliant-SG` listado como o recurso que violou a política, com o status `NON_COMPLIANT`.

**Passo 5: Configurar a Remediação Automática**
1.  Selecione a regra `restricted-ssh`.
2.  No menu **Actions**, clique em **"Manage remediation"**.
3.  **Remediation method:** `Automatic remediation`.
4.  **Remediation action:** Escolha a ação `AWS-DisablePublicAccessForSecurityGroup` (esta é uma ação de automação do AWS Systems Manager que remove regras de SG que permitem acesso público).
5.  **Resource ID parameter:** `GroupId` (o Config passará o ID do SG não conforme para a ação de remediação).
6.  **Parameters:** Configure os parâmetros para a ação de remediação:
    *   `IpProtocol`: `tcp`
    *   `FromPort`: `22`
    *   `ToPort`: `22`
    *   `CidrIp`: `0.0.0.0/0`
7.  Salve as alterações. O Config agora precisa de permissões para executar esta remediação. Ele pode solicitar a criação de uma nova IAM Role (`AWSServiceRoleForConfigRemediation`). Autorize.

**Passo 6: Testar a Remediação Automática**
1.  Para acionar a remediação novamente, vá para o `Non-Compliant-SG` e remova a regra SSH que você adicionou. Depois, adicione-a novamente. Isso cria um novo evento de mudança de configuração que o Config detectará.
2.  Volte para o **AWS Config** e observe a regra `restricted-ssh`. Ela se tornará não conforme novamente.
3.  Aguarde alguns minutos. O Config detectará a não conformidade e acionará a ação de remediação.
4.  Vá para a aba **"Remediation exception"** da regra. Você verá o status da ação de remediação mudar para `Action executed successfully`.
5.  **Validação Final:** Volte para o console da **VPC > Security Groups** e inspecione as regras de entrada do `Non-Compliant-SG`. A regra ofensiva que permitia SSH de `0.0.0.0/0` terá sido **removida automaticamente**.

Este laboratório demonstra o ciclo completo da governança na nuvem: definir uma política (a regra), detectar continuamente as violações e remediá-las automaticamente, garantindo que seu ambiente permaneça em um estado de conformidade conhecido e seguro.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Habilite o AWS Config:** Habilite o AWS Config em todas as contas e regiões onde você opera. Ele é a base para a auditoria contínua e a governança.
*   **Use Regras Gerenciadas:** Comece com as regras gerenciadas da AWS. Elas cobrem a maioria das melhores práticas de segurança e conformidade e são fáceis de implementar.
*   **Crie Regras Customizadas:** Para requisitos de conformidade específicos da sua organização, crie regras customizadas usando funções Lambda ou Guard.
*   **Automatize a Remediação:** Sempre que possível, configure a remediação automática para problemas comuns e de baixo risco. Isso reduz a carga operacional e garante a conformidade em tempo real.
*   **Pacotes de Conformidade:** Utilize pacotes de conformidade para implantar rapidamente um conjunto de regras e ações de remediação para frameworks de conformidade específicos (ex: PCI DSS, HIPAA).
*   **Centralize o Config:** Em ambientes multi-contas, centralize o AWS Config em uma conta de auditoria dedicada. Isso permite uma visão consolidada da conformidade em toda a organização.
*   **Integre com Security Hub:** O AWS Config envia seus findings de não conformidade para o AWS Security Hub, consolidando ainda mais sua visão de segurança.
*   **Monitore o Status de Conformidade:** Monitore o painel de conformidade do AWS Config e configure alarmes no CloudWatch para novas não conformidades ou falhas de remediação.
*   **Documentação:** Mantenha sua estratégia de conformidade e as regras do Config bem documentadas, explicando o propósito de cada regra e ação de remediação.