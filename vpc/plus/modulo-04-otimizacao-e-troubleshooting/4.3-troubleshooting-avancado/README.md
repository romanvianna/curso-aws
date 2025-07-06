# Módulo 4.3: Troubleshooting Avançado

**Tempo de Aula:** 60 minutos de teoria, 120 minutos de prática

## Pré-requisitos

*   Conhecimento sólido de VPCs, sub-redes, Security Groups, Network ACLs e tabelas de rotas.
*   Familiaridade com o console da AWS e a AWS CLI.
*   Compreensão dos conceitos de roteamento IP e firewalls stateful/stateless.
*   VPC Flow Logs habilitados e configurados para entrega em S3 (Módulo 3.1 do Advanced).

## Objetivos

*   Desenvolver uma metodologia sistemática para o troubleshooting de problemas de conectividade de rede na VPC, seguindo o fluxo de um pacote.
*   Aprender a usar o VPC Reachability Analyzer para diagnosticar problemas de configuração de rede de forma proativa e precisa.
*   Utilizar o VPC Flow Logs em conjunto com o Amazon Athena para análise forense de problemas de tráfego e identificação de padrões de comunicação.
*   Compreender e identificar problemas comuns de rede na AWS, como roteamento assimétrico.
*   Realizar a resolução de problemas em cenários complexos, aplicando as ferramentas e metodologias aprendidas.

---

## 1. Metodologias de Diagnóstico de Rede (Teoria - 60 min)

O troubleshooting de rede pode ser caótico se não for abordado com uma metodologia. Em vez de adivinhar, uma abordagem sistemática permite isolar o problema camada por camada. A melhor maneira de fazer isso é seguir o caminho que um pacote de dados percorreria, desde a origem até o destino e vice-versa.

### A Lista de Verificação de Conectividade (do Início ao Fim)

Quando uma Instância A não consegue se conectar a uma Instância B na porta X, siga esta lista de verificação, inspecionando cada ponto de controle:

**1. A Partir da Origem (Instância A):**
*   **Firewall do SO:** O firewall local na Instância A (ex: `iptables` no Linux, Firewall do Windows) está bloqueando o tráfego de saída para o destino na porta X?
*   **Security Group (Saída):** A regra de saída do Security Group da Instância A permite o tráfego para o destino (IP/CIDR da Instância B) na porta X?

**2. O Caminho da Rede (Da Sub-rede de Origem para a de Destino):**
*   **NACL da Sub-rede de Origem (Saída):** A NACL da sub-rede da Instância A permite o tráfego de saída para o destino na porta X (e portas efêmeras para a resposta)?
*   **Tabela de Rotas da Sub-rede de Origem:** Existe uma rota que corresponda ao endereço de destino (IP/CIDR da Instância B)? A rota aponta para o alvo correto (ex: `local`, IGW, TGW, VGW, ENI)?
*   **Roteamento Intermediário (se aplicável):** Se o tráfego passa por um Transit Gateway (TGW) ou Virtual Private Gateway (VGW), as tabelas de rotas desses gateways estão corretas e propagando as rotas necessárias?
*   **NACL da Sub-rede de Destino (Entrada):** A NACL da sub-rede da Instância B permite o tráfego de entrada da origem (IP/CIDR da Instância A) na porta X (e portas efêmeras para a resposta)?

**3. No Destino (Instância B):**
*   **Security Group (Entrada):** A regra de entrada do Security Group da Instância B permite o tráfego da origem (IP/CIDR da Instância A) na porta X?
*   **Firewall do SO:** O firewall local na Instância B está bloqueando o tráfego de entrada na porta X?
*   **Aplicação:** A aplicação está realmente escutando na porta X? (Use `netstat -an | grep LISTEN` ou `ss -tuln`).

### Ferramentas de Troubleshooting da AWS

A AWS fornece ferramentas poderosas para automatizar e simplificar essa lista de verificação, especialmente para problemas de configuração.

*   **VPC Reachability Analyzer:**
    *   **O que é:** Uma ferramenta de análise de configuração estática. Você especifica uma origem (ex: uma instância), um destino (ex: outra instância, um IP, um Load Balancer) e uma porta, e o Reachability Analyzer simula o caminho que um pacote percorreria, analisando todas as configurações de rede no caminho (SGs, NACLs, tabelas de rotas, etc.).
    *   **Como Funciona:** Ele não envia pacotes reais. Ele constrói um modelo matemático da sua configuração de rede e o atravessa. Se a conectividade for possível, ele mostra o caminho. Se for bloqueada, ele informa **exatamente qual componente** (ex: uma regra de negação na NACL, uma regra de SG ausente) está bloqueando o caminho e por quê.
    *   **Caso de Uso:** É uma ferramenta proativa para validar configurações antes da implantação. Também é excelente para diagnosticar rapidamente por que uma conexão existente parou de funcionar ou por que uma nova conexão não está funcionando.

*   **VPC Flow Logs com Amazon Athena:**
    *   **O que é:** Enquanto o Reachability Analyzer analisa a *configuração*, o Flow Logs registra o *tráfego real*. Ao habilitar o Flow Logs para serem entregues a um bucket S3, você pode usar o **Amazon Athena** (um serviço de consulta interativa) para executar consultas SQL complexas nesses logs.
    *   **Caso de Uso:** Para análise forense, auditoria e identificação de padrões de tráfego. Você pode responder a perguntas complexas como:
        *   `SELECT srcaddr, SUM(bytes) FROM vpc_flow_logs WHERE action = 'REJECT' GROUP BY srcaddr ORDER BY SUM(bytes) DESC;` (Quais são os principais IPs de origem que estão sendo rejeitados pelo meu firewall?)
        *   `SELECT * FROM vpc_flow_logs WHERE srcaddr = '1.2.3.4' AND dstport = 22;` (Mostre-me todas as tentativas de SSH do IP 1.2.3.4).
        *   `SELECT instance-id, SUM(bytes) FROM vpc_flow_logs WHERE action = 'ACCEPT' GROUP BY instance-id ORDER BY SUM(bytes) DESC;` (Quais instâncias estão gerando mais tráfego?)

### Problema Comum: Roteamento Assimétrico

*   **Conceito:** O roteamento assimétrico ocorre quando o caminho que o tráfego pega da origem para o destino é diferente do caminho que o tráfego de resposta pega do destino de volta para a origem.
*   **Por que é um problema?** Firewalls stateful (como Security Groups e AWS Network Firewall) e outros dispositivos de rede dependem de ver ambos os lados da conversa para rastrear o estado da conexão. Se um firewall vê o pacote de ida, mas o pacote de resposta passa por um caminho diferente e contorna o firewall, o firewall pode descartar a conexão por considerá-la inválida, resultando em timeouts.
*   **Causa Comum na AWS:** Isso pode acontecer em configurações de VPN complexas, com múltiplos gateways ou rotas mal configuradas. É crucial garantir que suas tabelas de rotas sejam consistentes para o tráfego de ida e de volta.

## 2. Resolução de Problemas Complexos (Prática - 120 min)

Neste laboratório, vamos simular um problema de conectividade e usar o VPC Reachability Analyzer e o Flow Logs para diagnosticar e resolver o problema. Isso simula um cenário de troubleshooting real em um ambiente de produção.

### Cenário: Conectividade Falha entre Aplicações

Uma equipe de desenvolvimento relata que a `Instance-A` (servidor web) não consegue se conectar à `Instance-B` (servidor de aplicação) na porta 8080, embora ambas estejam na mesma VPC. A conexão está falhando, e a causa é desconhecida. Vamos usar as ferramentas da AWS para diagnosticar o problema.

*   Temos uma `Instance-A` em uma `Subnet-A` e uma `Instance-B` em uma `Subnet-B` na mesma VPC.
*   A `Instance-A` precisa se conectar à `Instance-B` na porta 8080.
*   A conexão está falhando.

### Roteiro Prático

**Passo 1: Configurar o Cenário Quebrado**
1.  Crie uma VPC (`Troubleshoot-VPC`) com CIDR `10.50.0.0/16`.
2.  Crie duas sub-redes na mesma AZ (ex: `us-east-1a`):
    *   `Subnet-A`: `10.50.1.0/24`
    *   `Subnet-B`: `10.50.2.0/24`
3.  Lance duas instâncias EC2 (`t2.micro`, Amazon Linux 2), uma em cada sub-rede:
    *   `Instance-A` na `Subnet-A`.
    *   `Instance-B` na `Subnet-B`.
4.  Crie dois Security Groups, `SG-A` e `SG-B`.
    *   Em `SG-A` (associado à `Instance-A`), permita a saída para a porta 8080 para o CIDR da `Subnet-B` (`10.50.2.0/24`). Permita SSH do seu IP local.
    *   Em `SG-B` (associado à `Instance-B`), permita a entrada na porta 8080 a partir do CIDR da `Subnet-A` (`10.50.1.0/24`). Permita SSH do seu IP local.
5.  Crie duas NACLs, `NACL-A` e `NACL-B`, e associe-as às suas respectivas sub-redes.
    *   **A Causa do Problema:** Na `NACL-B` (associada à `Subnet-B`), adicione uma regra de entrada com um número baixo (ex: 90) que **NEGA (`DENY`)** todo o tráfego TCP vindo do CIDR da `Subnet-A` (`10.50.1.0/24`) na porta 8080.

**Passo 2: Diagnóstico com VPC Reachability Analyzer**
1.  Navegue até **VPC > Reachability Analyzer > Create and analyze path**.
2.  **Source type:** `Instances`, e selecione `Instance-A`.
3.  **Destination type:** `Instances`, e selecione `Instance-B`.
4.  **Protocol:** `TCP`.
5.  **Destination port:** `8080`.
6.  Clique em **"Create and analyze path"**. A análise pode levar um ou dois minutos.
7.  **Analisar o Resultado:**
    *   O status da análise será **`Not reachable`**.
    *   O painel de explicação mostrará o caminho passo a passo. Ele mostrará que o tráfego passou pelo SG de saída, pela NACL de saída, pela tabela de rotas, mas foi bloqueado ao chegar na sub-rede de destino.
    *   Ele destacará o componente que bloqueou o tráfego: a `NACL-B`.
    *   Ele citará a regra específica (`Rule number 90`) que causou a negação.

**Passo 3: Corrigir o Problema e Reanalisar**
1.  Com base no diagnóstico, vá para a `NACL-B` e remova a regra de negação número 90.
2.  Volte para o Reachability Analyzer e clique em **"Analyze path"** novamente na análise salva.
3.  **Novo Resultado:** O status agora será **`Reachable`**, e ele mostrará o caminho completo e bem-sucedido.

**Passo 4: Análise Forense com Flow Logs e Athena**
*Este passo assume que o Flow Logs está habilitado para a VPC e enviando para o S3 (conforme Módulo 3.1 do Advanced).*
1.  **Cenário:** Imagine que você não sabia qual porta estava sendo bloqueada. Você só sabe que a `Instance-A` não consegue se conectar à `Instance-B`.
2.  Vá para o **Amazon Athena**.
3.  Se ainda não o fez, crie uma tabela para seus VPC Flow Logs que aponte para o bucket S3 onde seus logs estão sendo armazenados. (A AWS fornece um template de `CREATE TABLE` para isso na documentação do Flow Logs).
4.  **Execute uma Consulta SQL para Encontrar Rejeições:**
    ```sql
    SELECT
      from_unixtime(start_time) AS start_timestamp,
      srcaddr,
      dstaddr,
      dstport,
      action
    FROM
      "your_flow_log_database"."your_flow_log_table" -- Substitua pelo nome do seu banco de dados e tabela
    WHERE
      action = 'REJECT'
      AND srcaddr = 'IP_PRIVADO_DA_INSTANCE_A' -- Substitua pelo IP privado da Instance-A
      AND dstaddr = 'IP_PRIVADO_DA_INSTANCE_B' -- Substitua pelo IP privado da Instance-B
    ORDER BY
      start_timestamp DESC
    LIMIT 10;
    ```
5.  **Análise do Resultado:** A consulta retornará uma lista de todas as conexões rejeitadas da Instância A para a Instância B, mostrando a porta de destino (`dstport`) que estava sendo bloqueada e a ação (`REJECT`). Isso permite que você identifique rapidamente qual serviço ou porta está com problemas e qual componente de segurança (NACL, SG) o rejeitou (se o Flow Log estiver configurado para registrar o `log-status`).

Este laboratório demonstra uma abordagem de troubleshooting de duas frentes: usar o Reachability Analyzer para análise de configuração proativa e rápida, e usar o Flow Logs com o Athena para análise de tráfego real e investigações forenses mais profundas.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Metodologia Sistemática:** Sempre siga uma metodologia de troubleshooting (como a lista de verificação de conectividade) para evitar adivinhações e garantir que você cubra todos os pontos de controle de rede.
*   **VPC Reachability Analyzer:** Use-o como sua primeira ferramenta para diagnosticar problemas de conectividade. Ele é rápido, não intrusivo e aponta exatamente onde a configuração está errada.
*   **VPC Flow Logs:** Habilite o Flow Logs para todas as suas VPCs. Eles são inestimáveis para análise forense, auditoria e para entender o tráfego real que flui (ou não flui) pela sua rede. Use o Amazon Athena para consultar grandes volumes de logs.
*   **CloudTrail:** Use o CloudTrail para auditar as mudanças de configuração. Se algo parou de funcionar, o CloudTrail pode mostrar quem fez a última alteração em um Security Group, NACL ou tabela de rotas.
*   **Firewall do SO:** Não se esqueça de verificar o firewall do sistema operacional (ex: `iptables`, `firewalld`, Firewall do Windows) nas instâncias. Muitas vezes, a conectividade é bloqueada lá.
*   **Ferramentas de Diagnóstico no SO:** Use ferramentas como `ping`, `traceroute`, `netstat`, `ss`, `telnet`, `nc` (netcat) diretamente nas instâncias para testar a conectividade de dentro para fora e de fora para dentro.
*   **Roteamento Assimétrico:** Esteja ciente do roteamento assimétrico, especialmente em configurações de VPN complexas ou com múltiplos caminhos de rede. Garanta que o tráfego de ida e volta siga o mesmo caminho através de firewalls stateful.
*   **Documentação:** Mantenha sua arquitetura de rede bem documentada, incluindo blocos CIDR, tabelas de rotas, regras de SG e NACL. Isso acelera o troubleshooting.