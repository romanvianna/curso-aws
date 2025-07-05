# Módulo 3.1: Criando e Analisando Logs

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Pré-requisitos

*   Conhecimento básico de redes TCP/IP.
*   Familiaridade com os conceitos de VPC, sub-redes e instâncias EC2.
*   Noções básicas de armazenamento em S3 e CloudWatch.

## Objetivos

*   Entender a observabilidade como um conceito que vai além do monitoramento tradicional.
*   Posicionar o VPC Flow Logs como a principal ferramenta para observabilidade do tráfego de rede.
*   Posicionar o AWS CloudTrail como a principal ferramenta para auditoria de segurança e governança.
*   Habilitar e configurar ambos os serviços, realizando uma análise forense básica de eventos de rede e de API.
*   Discutir a importância dos logs para segurança, troubleshooting e conformidade em ambientes de produção.

---

## 1. Os Pilares da Observabilidade na Nuvem (Teoria - 45 min)

**Observabilidade** é a capacidade de medir o estado interno de um sistema apenas examinando suas saídas. Em um sistema de nuvem complexo, isso significa ser capaz de responder a perguntas que você não sabia que precisaria fazer. Enquanto o monitoramento tradicional se concentra em métricas conhecidas (CPU, memória), a observabilidade se concentra em dados brutos e de alta cardinalidade: **logs** e **traces**.

Para a VPC e a conta AWS como um todo, existem duas fontes de dados (logs) que são a base da observabilidade:

### 1. VPC Flow Logs: Observabilidade do Plano de Dados

O **plano de dados (data plane)** de uma rede é por onde os dados dos usuários realmente fluem. O VPC Flow Logs nos dá visibilidade sobre este plano.

*   **O que é?** Um registro de **todos os fluxos de tráfego IP** (aceitos e rejeitados) que passam por uma interface de rede (ENI), uma sub-rede ou uma VPC inteira. Um "fluxo" é uma sequência de pacotes com as mesmas 5 tuplas: IP de origem, porta de origem, IP de destino, porta de destino e protocolo.

*   **Por que é crucial?**
    *   **Análise de Segurança Forense:** Se ocorrer um incidente de segurança, os Flow Logs são sua "caixa-preta". Você pode reconstruir o que aconteceu, respondendo a perguntas como: "O invasor tentou se mover lateralmente para outras instâncias? Quais portas ele escaneou? De onde veio o tráfego malicioso?" Isso é vital para investigações pós-incidente.
    *   **Troubleshooting de Rede Detalhado:** Um Security Group está bloqueando uma conexão? Uma NACL está rejeitando o tráfego? Os Flow Logs mostram explicitamente a ação (`ACCEPT` ou `REJECT`) e qual camada de segurança a tomou, tornando o diagnóstico muito mais rápido e preciso.
    *   **Análise de Dependência de Aplicações:** Ao analisar os fluxos, você pode descobrir com quais outros sistemas uma aplicação está se comunicando, o que é vital para planejar migrações, refatorar arquiteturas ou entender dependências ocultas.
    *   **Otimização de Custos:** Identificar tráfego desnecessário ou mal configurado que pode estar gerando custos de transferência de dados.

*   **Formato do Log:** Cada registro é uma linha de texto com campos como `srcaddr`, `dstaddr`, `srcport`, `dstport`, `protocol`, `action`. Você pode customizar o formato para incluir metadados valiosos como `vpc-id`, `subnet-id`, `instance-id`, `tcp-flags` (para identificar pacotes SYN, FIN, etc.) e `pkt-srcaddr`/`pkt-dstaddr` (para ver os IPs originais antes do NAT).

### 2. AWS CloudTrail: Observabilidade do Plano de Controle

O **plano de controle (control plane)** é como você gerencia e configura a rede. São as ações que mudam o estado da sua infraestrutura (criar uma VPC, modificar um Security Group, etc.). O AWS CloudTrail nos dá visibilidade sobre este plano.

*   **O que é?** Um registro de **todas as chamadas de API** feitas na sua conta AWS. Cada ação que você realiza no console, na CLI ou via SDK é uma chamada de API. O CloudTrail registra o evento, quem o fez, quando, de onde e o resultado.

*   **Por que é crucial?**
    *   **Auditoria de Segurança e Conformidade:** O CloudTrail é a fonte da verdade para responder "Quem fez o quê, quando e de onde?". É um requisito fundamental para a maioria dos padrões de conformidade (PCI, HIPAA, SOC 2, GDPR, LGPD).
    *   **Detecção de Ameaças:** Você pode monitorar atividades suspeitas no plano de controle. Exemplos:
        *   Um usuário desativando o CloudTrail ou o VPC Flow Logs (um forte indicador de atividade maliciosa).
        *   Múltiplas tentativas falhas de login (tentativa de força bruta).
        *   Criação de usuários IAM ou chaves de acesso fora do horário comercial.
        *   Alterações em regras de firewall críticas (Security Groups, NACLs).
    *   **Análise de Causa Raiz Operacional:** Uma aplicação parou de funcionar? Talvez alguém tenha modificado um Security Group, deletado uma tabela de rotas ou alterado uma configuração crítica. O CloudTrail permite que você correlacione as mudanças na infraestrutura com os incidentes da aplicação.

---

## 2. Configuração e Análise Forense (Prática - 75 min)

Neste laboratório, vamos habilitar o VPC Flow Logs e o CloudTrail, gerar eventos suspeitos e normais, e depois usar o CloudWatch Logs Insights para analisar os dados. Isso simula um cenário de investigação de segurança ou troubleshooting em um ambiente de produção.

### Cenário: Investigação de Segurança e Troubleshooting de Rede

Uma empresa percebeu um comportamento anômalo em sua rede e precisa investigar. Há suspeitas de que um servidor foi comprometido e está tentando se comunicar com IPs externos não autorizados, e também houve uma alteração não planejada em um Security Group. Usaremos VPC Flow Logs e CloudTrail para coletar evidências e o CloudWatch Logs Insights para analisá-las.

### Roteiro Prático

**Passo 1: Habilitar VPC Flow Logs para o S3**
1.  Navegue até o console da **VPC** > sua `Lab-VPC` > aba **"Flow Logs"** > **"Create flow log"**.
2.  **Name:** `lab-vpc-flow-log`
3.  **Filter:** `All` (para capturar tráfego aceito e rejeitado).
4.  **Destination:** Selecione **"Send to an S3 bucket"**. (Enviar para o S3 é mais barato para armazenamento de longo prazo e análise em massa com ferramentas como o Amazon Athena ou ferramentas de SIEM).
5.  **S3 bucket ARN:** Forneça o ARN de um bucket S3 que você criou para este propósito (ex: `arn:aws:s3:::my-vpc-flow-logs-bucket-unique`). Certifique-se de que o bucket tem as permissões corretas para receber logs.
6.  **Log record format:** Selecione **"Custom format"** e inclua campos úteis para análise forense e troubleshooting:
    `version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status vpc-id subnet-id instance-id tcp-flags type pkt-srcaddr pkt-dstaddr`
7.  Clique em **"Create flow log"**. O provisionamento pode levar alguns minutos.

**Passo 2: Habilitar AWS CloudTrail**
1.  Navegue até o **CloudTrail** > **"Trails"** > **"Create trail"**.
2.  **Trail name:** `organization-wide-trail` (ou um nome descritivo).
3.  **Apply trail to my organization:** Se estiver em uma AWS Organization, habilite isso para ter uma trilha centralizada que registra eventos de todas as contas membros. Caso contrário, deixe desabilitado.
4.  **Storage location:** Crie ou selecione um bucket S3 para armazenamento de longo prazo dos logs do CloudTrail.
5.  **CloudWatch Logs:** Habilite o envio para o CloudWatch Logs para análise em tempo real e criação de alarmes. Crie um novo grupo de logs (ex: `CloudTrail/Default`) e uma nova role IAM para o CloudTrail.
6.  Clique em **"Next"**. Mantenha **"Management events"** selecionado (para registrar ações de controle) e clique em **"Create trail"**.

**Passo 3: Gerar Eventos para Análise**

Para simular um ambiente real, vamos gerar alguns eventos que poderíamos querer investigar:

1.  **Evento de Rede Suspeito (Simulando Escaneamento de Portas):**
    *   A partir do seu `Lab-WebServer` (ou qualquer instância na sua VPC), tente escanear portas em outra instância (`Lab-DBServer`) usando `nmap` (pode ser necessário instalar: `sudo yum install nmap -y`).
        `nmap -p 1-1024 IP_PRIVADO_DO_DBSERVER`
    *   Isso gerará entradas no VPC Flow Logs com a ação `REJECT` para as portas fechadas.

2.  **Evento de Rede Normal (Simulando Acesso Web):**
    *   Acesse um site a partir do `Lab-WebServer`: `curl https://www.amazon.com`
    *   Isso gerará entradas no VPC Flow Logs com a ação `ACCEPT`.

3.  **Evento de API Suspeito (Simulando Alteração de Segurança):**
    *   No console da AWS, vá para um Security Group não crítico e adicione uma regra de entrada permitindo RDP (`3389`) de `0.0.0.0/0`. Depois, remova-a.
    *   Isso gerará eventos `AuthorizeSecurityGroupIngress` e `RevokeSecurityGroupIngress` no CloudTrail.

**Passo 4: Analisar os Logs com CloudWatch Logs Insights**
*Pode levar de 5 a 15 minutos para os logs aparecerem no CloudWatch Logs Insights.*

1.  **Analisar Logs do CloudTrail (no CloudWatch Logs Insights):**
    *   Navegue até **CloudWatch** > **Log groups** > seu grupo de logs do CloudTrail (ex: `CloudTrail/Default`).
    *   Clique em **"Logs Insights"** no menu.
    *   **Consulta 1: Encontrar a alteração no Security Group.**
        ```sql
        fields @timestamp, eventName, userIdentity.arn, sourceIPAddress, requestParameters.groupId, responseElements.return
        | filter eventName = 'AuthorizeSecurityGroupIngress' or eventName = 'RevokeSecurityGroupIngress'
        | sort @timestamp desc
        ```
        Isso mostrará exatamente quem (`userIdentity`), quando (`@timestamp`), de qual IP (`sourceIPAddress`) abriu e fechou a porta, e qual Security Group foi afetado.

    *   **Consulta 2: Procurar por logins falhos no console.**
        ```sql
        fields @timestamp, eventName, userIdentity.userName, sourceIPAddress, errorMessage
        | filter eventName = 'ConsoleLogin' and errorMessage = 'Failed authentication'
        | sort @timestamp desc
        ```

2.  **Analisar VPC Flow Logs (no S3 com Amazon Athena - Método Avançado):**
    *   Para grandes volumes de Flow Logs no S3, o Amazon Athena é a ferramenta ideal. Você pode criar uma tabela externa no Athena que aponta para o seu bucket S3 de Flow Logs e, em seguida, executar consultas SQL para encontrar padrões.
    *   **Exemplo de Consulta Athena para Flow Logs:**
        ```sql
        SELECT srcaddr, dstaddr, dstport, action, COUNT(*) as flow_count
        FROM "your_flow_log_database"."your_flow_log_table"
        WHERE action = 'REJECT'
        GROUP BY srcaddr, dstaddr, dstport, action
        ORDER BY flow_count DESC;
        ```
        Esta consulta identificaria os IPs de origem que estão tentando se conectar a portas que são rejeitadas, indicando possíveis escaneamentos ou configurações incorretas.

Este laboratório demonstra como habilitar os serviços de observabilidade e, mais importante, como usar ferramentas de análise como o Logs Insights e o Athena para consultar ativamente esses dados, permitindo que você investigue incidentes, audite a conformidade e entenda o comportamento do seu ambiente.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Habilite Logs Desde o Início:** Configure VPC Flow Logs e CloudTrail desde o início do seu ambiente AWS. Eles são cruciais para segurança, conformidade e troubleshooting.
*   **Formato de Log Customizado:** Para VPC Flow Logs, use o formato customizado para incluir metadados adicionais que são úteis para sua análise (ex: `instance-id`, `tcp-flags`).
*   **Destino dos Logs:** Para armazenamento de longo prazo e análise em larga escala, envie os logs para o S3. Para análise em tempo real e alarmes, envie para o CloudWatch Logs.
*   **Retenção de Logs:** Defina políticas de retenção de logs apropriadas para S3 e CloudWatch Logs com base nos seus requisitos de conformidade e auditoria.
*   **Monitoramento de Atividade Suspeita:** Crie alarmes no CloudWatch para eventos críticos do CloudTrail (ex: desativação de logs, criação de usuários root, tentativas de login falhas).
*   **Centralize Logs:** Em ambientes multi-conta, use o AWS Organizations para centralizar os logs do CloudTrail e do VPC Flow Logs em uma conta de log dedicada.
*   **Use Ferramentas de Análise:** Não apenas colete logs, mas use ferramentas como CloudWatch Logs Insights, Amazon Athena, ou soluções de SIEM (Security Information and Event Management) para analisar e extrair valor dos seus dados de log.
*   **Teste suas Consultas:** Regularmente teste suas consultas de log para garantir que elas estão capturando os eventos que você espera e fornecendo as informações necessárias.
