# Módulo 3.1: Criando e Analisando Logs

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Objetivos

- Entender a observabilidade como um conceito que vai além do monitoramento tradicional.
- Posicionar o VPC Flow Logs como a principal ferramenta para observabilidade do tráfego de rede.
- Posicionar o AWS CloudTrail como a principal ferramenta para auditoria de segurança e governança.
- Habilitar e configurar ambos os serviços, realizando uma análise forense básica de eventos de rede e de API.

---

## 1. Os Pilares da Observabilidade na Nuvem (Teoria - 45 min)

**Observabilidade** é a capacidade de medir o estado interno de um sistema apenas examinando suas saídas. Em um sistema de nuvem complexo, isso significa ser capaz de responder a perguntas que você não sabia que precisaria fazer. Enquanto o monitoramento tradicional se concentra em métricas conhecidas (CPU, memória), a observabilidade se concentra em dados brutos e de alta cardinalidade: **logs** e **traces**.

Para a VPC e a conta AWS como um todo, existem duas fontes de dados (logs) que são a base da observabilidade:

### 1. VPC Flow Logs: Observabilidade do Plano de Dados

O **plano de dados (data plane)** de uma rede é por onde os dados dos usuários realmente fluem. O VPC Flow Logs nos dá visibilidade sobre este plano.

-   **O que é?** Um registro de **todos os fluxos de tráfego IP** (aceitos e rejeitados) que passam por uma interface de rede (ENI), uma sub-rede ou uma VPC inteira. Um "fluxo" é uma sequência de pacotes com as mesmas 5 tuplas: IP de origem, porta de origem, IP de destino, porta de destino e protocolo.

-   **Por que é crucial?**
    -   **Análise de Segurança Forense:** Se ocorrer um incidente de segurança, os Flow Logs são sua "caixa-preta". Você pode reconstruir o que aconteceu, respondendo a perguntas como: "O invasor tentou se mover lateralmente para outras instâncias? Quais portas ele escaneou? De onde veio o tráfego malicioso?".
    -   **Troubleshooting de Rede Detalhado:** Um Security Group está bloqueando uma conexão? Uma NACL está rejeitando o tráfego? Os Flow Logs mostram explicitamente a ação (`ACCEPT` ou `REJECT`) e qual camada de segurança a tomou, tornando o diagnóstico muito mais rápido.
    -   **Análise de Dependência de Aplicações:** Ao analisar os fluxos, você pode descobrir com quais outros sistemas uma aplicação está se comunicando, o que é vital para planejar migrações ou entender arquiteturas complexas.

-   **Formato do Log:** Cada registro é uma linha de texto com campos como `srcaddr`, `dstaddr`, `srcport`, `dstport`, `protocol`, `action`. Você pode customizar o formato para incluir metadados valiosos como `vpc-id`, `subnet-id`, `instance-id`, `tcp-flags` (para identificar pacotes SYN, FIN, etc.) e `pkt-srcaddr`/`pkt-dstaddr` (para ver os IPs originais antes do NAT).

### 2. AWS CloudTrail: Observabilidade do Plano de Controle

O **plano de controle (control plane)** é como você gerencia e configura a rede. São as ações que mudam o estado da sua infraestrutura (criar uma VPC, modificar um Security Group, etc.). O AWS CloudTrail nos dá visibilidade sobre este plano.

-   **O que é?** Um registro de **todas as chamadas de API** feitas na sua conta AWS. Cada ação que você realiza no console, na CLI ou via SDK é uma chamada de API.

-   **Por que é crucial?**
    -   **Auditoria de Segurança e Conformidade:** O CloudTrail é a fonte da verdade para responder "Quem fez o quê, quando e de onde?". É um requisito fundamental para a maioria dos padrões de conformidade (PCI, HIPAA, SOC 2).
    -   **Detecção de Ameaças:** Você pode monitorar atividades suspeitas no plano de controle. Exemplos:
        -   Um usuário desativando o CloudTrail ou o VPC Flow Logs (um forte indicador de atividade maliciosa).
        -   Múltiplas tentativas falhas de login (tentativa de força bruta).
        -   Criação de usuários IAM ou chaves de acesso fora do horário comercial.
        -   Alterações em regras de firewall críticas (Security Groups, NACLs).
    -   **Análise de Causa Raiz Operacional:** Uma aplicação parou de funcionar? Talvez alguém tenha modificado um Security Group ou deletado uma tabela de rotas. O CloudTrail permite que você correlacione as mudanças na infraestrutura com os incidentes da aplicação.

---

## 2. Configuração e Análise Forense (Prática - 75 min)

Neste laboratório, vamos habilitar o VPC Flow Logs e o CloudTrail, gerar eventos suspeitos e normais, e depois usar o CloudWatch Logs Insights para analisar os dados.

### Roteiro Prático

**Passo 1: Habilitar VPC Flow Logs para o S3**
1.  Navegue até o console da **VPC** > sua `Lab-VPC` > aba **"Flow Logs"** > **"Create flow log"**.
2.  **Name:** `lab-vpc-flow-log`
3.  **Filter:** `All`.
4.  **Destination:** Selecione **"Send to an S3 bucket"**. (Enviar para o S3 é mais barato para armazenamento de longo prazo e análise em massa com ferramentas como o Athena).
5.  **S3 bucket ARN:** Forneça o ARN de um bucket S3 que você criou para este propósito.
6.  **Log record format:** Selecione **"Custom format"** e inclua campos úteis como `vpc-id`, `subnet-id`, `instance-id`, `tcp-flags`.
7.  Clique em **"Create flow log"**.

**Passo 2: Habilitar AWS CloudTrail**
1.  Navegue até o **CloudTrail** > **"Create a trail"**.
2.  **Trail name:** `organization-wide-trail`
3.  **Apply trail to my organization:** Se estiver em uma organização, habilite isso para ter uma trilha centralizada.
4.  **Storage location:** Crie ou selecione um bucket S3 para armazenamento de longo prazo.
5.  **CloudWatch Logs:** Habilite o envio para o CloudWatch Logs para análise em tempo real.
6.  Clique em **"Next"**. Mantenha **"Management events"** selecionado e clique em **"Create trail"**.

**Passo 3: Gerar Eventos para Análise**
1.  **Evento de Rede Suspeito:**
    -   A partir do seu `Lab-WebServer`, tente escanear portas no `Lab-DBServer` usando `nmap` (pode ser necessário instalar: `sudo yum install nmap -y`).
        `nmap -p 1-1024 IP_PRIVADO_DO_DBSERVER`
2.  **Evento de Rede Normal:**
    -   Acesse um site a partir do `Lab-WebServer`: `curl https://www.amazon.com`
3.  **Evento de API Suspeito:**
    -   No console, vá para um Security Group não crítico e adicione uma regra de entrada permitindo RDP (`3389`) de `0.0.0.0/0`. Depois, remova-a.

**Passo 4: Analisar os Logs com CloudWatch Logs Insights**
*Pode levar de 5 a 15 minutos para os logs aparecerem.*

1.  **Analisar VPC Flow Logs (no S3 com Athena):**
    -   (Método Avançado) Vá para o Amazon Athena, crie uma tabela sobre os dados do Flow Log no S3 e execute consultas SQL para encontrar padrões.

2.  **Analisar Logs do CloudTrail (no CloudWatch):**
    -   Navegue até **CloudWatch** > **Log groups** > seu grupo de logs do CloudTrail.
    -   Clique em **"Logs Insights"** no menu.
    -   **Consulta 1: Encontrar a alteração no Security Group.**
        ```sql
        fields eventTime, eventName, userIdentity.arn, sourceIPAddress, requestParameters.groupId
        | filter eventName = 'AuthorizeSecurityGroupIngress' or eventName = 'RevokeSecurityGroupIngress'
        | sort eventTime desc
        ```
        Isso mostrará exatamente quem (`userIdentity`) abriu e fechou a porta, quando e de qual IP.

    -   **Consulta 2: Procurar por logins falhos no console.**
        ```sql
        fields eventTime, eventName, sourceIPAddress, errorMessage
        | filter eventName = 'ConsoleLogin' and errorMessage = 'Failed authentication'
        | sort eventTime desc
        ```

Este laboratório demonstra como habilitar os serviços de observabilidade e, mais importante, como usar ferramentas de análise como o Logs Insights para consultar ativamente esses dados, permitindo que você investigue incidentes, audite a conformidade e entenda o comportamento do seu ambiente.