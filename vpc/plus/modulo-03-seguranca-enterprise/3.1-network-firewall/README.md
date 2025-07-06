# Módulo 3.1: AWS Network Firewall

**Tempo de Aula:** 90 minutos de teoria, 90 minutos de prática

## Pré-requisitos

*   Conhecimento sólido dos conceitos de Security Groups e Network ACLs (Módulo 2.1).
*   Familiaridade com o modelo OSI (Camadas 3 e 4).
*   Compreensão de roteamento em VPCs e Transit Gateway (Módulo 1.2 do Plus).
*   Noções básicas de firewalls e sistemas de prevenção de intrusão (IPS).

## Objetivos

*   Entender as limitações dos Security Groups e NACLs para inspeção de tráfego avançada e por que firewalls de próxima geração (NGFW) são necessários.
*   Aprender sobre firewalls de próxima geração (NGFW) e sistemas de prevenção de intrusão (IPS), incluindo conceitos como Deep Packet Inspection (DPI) e filtragem de URL/domínio.
*   Posicionar o AWS Network Firewall como um serviço de firewall de rede gerenciado e stateful, que oferece funcionalidades de NGFW e IPS.
*   Analisar os componentes do Network Firewall: Política de Firewall, Grupos de Regras Stateless e Stateful (incluindo regras Suricata).
*   Compreender a arquitetura de implantação recomendada para o Network Firewall, especialmente o padrão de VPC de Inspeção Centralizada.
*   Implementar o Network Firewall em uma VPC de inspeção para filtrar o tráfego de forma centralizada, demonstrando a filtragem de domínio.

---

## 1. Inspeção de Tráfego de Rede Avançada (Teoria - 90 min)

Até agora, nossas ferramentas de firewall (Security Groups e NACLs) operam principalmente nas **Camadas 3 (Rede) e 4 (Transporte)** do modelo OSI. Elas tomam decisões com base em endereços IP e portas. Elas são excelentes para controle de acesso e segmentação básica, mas não conseguem inspecionar o **conteúdo** do tráfego.

Elas não conseguem responder a perguntas como:

*   "Este tráfego na porta 80 é uma requisição HTTP legítima ou é um ataque de SQL Injection sendo tunelado por essa porta?"
*   "Este download de arquivo contém um malware conhecido?"
*   "Um servidor interno está tentando se comunicar com um domínio conhecido de comando e controle (C2) de botnets?"

Para responder a essas perguntas e fornecer uma camada de segurança mais profunda, precisamos de um **Firewall de Próxima Geração (NGFW)**.

### O que é um NGFW?

Um NGFW combina as funcionalidades de um firewall tradicional (filtragem de pacotes stateful) com recursos de segurança mais avançados:

*   **Inspeção Profunda de Pacotes (DPI - Deep Packet Inspection):** A capacidade de examinar o conteúdo real (o payload) dos pacotes, não apenas seus cabeçalhos. Isso permite identificar aplicações, ameaças e dados sensíveis.
*   **Sistema de Prevenção de Intrusão (IPS - Intrusion Prevention System):** Usa um banco de dados de assinaturas de ataques conhecidos para identificar e bloquear tráfego malicioso em tempo real. Pode detectar e prevenir ataques como injeção de SQL, cross-site scripting (XSS) e estouro de buffer.
*   **Filtragem de URL/Domínio:** Bloqueia o acesso a sites ou domínios com base em sua categoria (ex: malware, phishing, redes sociais) ou em listas de reputação (ex: bloquear acesso a domínios maliciosos conhecidos).
*   **Prevenção de Perda de Dados (DLP - Data Loss Prevention):** Pode inspecionar o tráfego de saída para detectar e bloquear a exfiltração de dados sensíveis (ex: números de cartão de crédito, informações de identificação pessoal - PII).

### AWS Network Firewall: Um NGFW Gerenciado

O **AWS Network Firewall** é um serviço gerenciado que facilita a implantação de proteções de rede essenciais para todas as suas VPCs. Ele fornece a funcionalidade de um NGFW/IPS sem a necessidade de implantar e gerenciar appliances de firewall de terceiros (como EC2 instances com software de firewall).

**Componentes do Network Firewall:**

1.  **Política de Firewall (Firewall Policy):** O contêiner de mais alto nível. Ele define o comportamento geral do firewall, agrupando grupos de regras stateful e stateless. Uma política de firewall pode ser reutilizada por múltiplos firewalls.

2.  **Grupos de Regras Stateless:**
    *   Similares às NACLs. Processam pacotes com base em IP, porta e protocolo. São avaliadas primeiro pela sua velocidade. A principal função é permitir ou negar tráfego de forma rápida ou passá-lo para o motor de regras stateful. Podem ser usadas para permitir tráfego "limpo" que não precisa de inspeção profunda.

3.  **Grupos de Regras Stateful:**
    *   Este é o coração do serviço. O motor stateful inspeciona o tráfego no contexto de sua conexão, permitindo regras mais complexas e inteligentes.
    *   **Regras de Domínio (Domain List):** Permitem ou negam o tráfego com base no nome de domínio (FQDN) solicitado (ex: `deny *.example.com`). Útil para controlar acesso a sites específicos.
    *   **Regras de Assinatura IPS (Suricata Compatible):** O Network Firewall suporta regras escritas na sintaxe do **Suricata**, um popular motor de IPS de código aberto. A AWS fornece grupos de regras gerenciadas para ameaças conhecidas (malware, botnets, etc.), e você pode escrever as suas próprias regras personalizadas para detectar padrões de tráfego específicos.
    *   **Regras de 5-tuplas:** Permitem regras stateful baseadas em IP de origem/destino, porta de origem/destino e protocolo.

### Arquitetura de Implantação: VPC de Inspeção Centralizada

Para evitar a implantação de um firewall em cada VPC (o que seria caro e complexo de gerenciar), o padrão de arquitetura recomendado é criar uma **VPC de Inspeção** centralizada.

*   **Como Funciona:**
    1.  Você cria uma VPC dedicada (`Inspection-VPC`) em uma conta de rede centralizada.
    2.  Você implanta os **endpoints do Network Firewall** em sub-redes dentro desta VPC (um endpoint por AZ para alta disponibilidade).
    3.  Você usa um **Transit Gateway** para rotear o tráfego de suas VPCs de aplicação (spokes) para a Inspection-VPC antes que ele vá para a internet ou para outras VPCs.
    4.  Dentro da Inspection-VPC, tabelas de rotas inteligentes forçam o tráfego a passar pelo endpoint do firewall para ser inspecionado.

*   **Fluxo de Tráfego (Exemplo: Saída para a Internet):**
    1.  Instância na VPC-A (Spoke) envia tráfego para a internet.
    2.  A tabela de rotas da VPC-A envia todo o tráfego (`0.0.0.0/0`) para o Transit Gateway.
    3.  O TGW consulta sua tabela de rotas, que direciona o tráfego para o anexo da `Inspection-VPC`.
    4.  O tráfego chega à `Inspection-VPC`. A tabela de rotas da sub-rede do anexo do TGW o envia para o **endpoint do Network Firewall**.
    5.  O firewall inspeciona o tráfego com base nas regras configuradas. Se for permitido, ele o envia para uma sub-rede pública na `Inspection-VPC` que contém um NAT Gateway.
    6.  O NAT Gateway envia o tráfego para o Internet Gateway e para a internet.

Esta arquitetura centraliza a inspeção, garantindo que todo o tráfego de e para suas VPCs seja filtrado por um único ponto de controle, simplificando o gerenciamento e a aplicação de políticas de segurança em escala.

## 2. Implementação do Network Firewall (Prática - 90 min)

Neste laboratório, vamos configurar uma arquitetura simplificada para demonstrar o poder de filtragem de domínio do Network Firewall. O objetivo é entender o fluxo de tráfego através do firewall e como as regras de domínio funcionam.

### Cenário: Filtragem de Acesso à Internet para Aplicações

Uma empresa deseja controlar o acesso à internet de suas aplicações. Eles querem permitir o acesso a domínios específicos (ex: `amazon.com`) para atualizações e APIs, mas bloquear o acesso a outros domínios (ex: `google.com`) por política de segurança ou para evitar exfiltração de dados. Usaremos o AWS Network Firewall para impor essa política.

*   Temos uma VPC (`FW-VPC`) com uma instância EC2.
*   **Objetivo:** Usar o Network Firewall para permitir que a instância acesse `www.amazon.com`, mas bloquear explicitamente o acesso a `www.google.com`.

### Roteiro Prático

**Passo 1: Criar a VPC e Sub-redes Necessárias**
1.  Crie uma VPC (`FW-VPC`) com CIDR `10.40.0.0/16`.
2.  Crie três sub-redes nesta VPC (todas na mesma AZ para simplicidade do lab, ex: `us-east-1a`):
    *   `Subnet-App` (onde nossa instância viverá): `10.40.1.0/24`
    *   `Subnet-Firewall` (onde o endpoint do FW viverá): `10.40.2.0/24`
    *   `Subnet-Public` (com um IGW e NAT GW para acesso à internet): `10.40.3.0/24`

**Passo 2: Configurar o Acesso à Internet (IGW e NAT Gateway)**
1.  Crie um Internet Gateway (`FW-IGW`) e anexe-o à `FW-VPC`.
2.  Crie um Elastic IP (`FW-NAT-EIP`) e um NAT Gateway (`FW-NAT-GW`) na `Subnet-Public`.
3.  Crie uma tabela de rotas (`FW-Public-RT`) para a `Subnet-Public` com uma rota `0.0.0.0/0` apontando para o `FW-IGW`. Associe-a à `Subnet-Public`.

**Passo 3: Criar e Configurar o Network Firewall**
1.  Navegue até **VPC > Network Firewall > Firewalls > Create firewall**.
2.  **Name:** `Lab-Firewall`
3.  **VPC:** Selecione sua `FW-VPC`.
4.  **Availability Zones:** Selecione a AZ onde você criou suas sub-redes e, para a sub-rede do firewall, escolha a `Subnet-Firewall`.
5.  **Firewall policy:** Selecione **"Create and associate a new firewall policy"**.
6.  **Na criação da política:**
    *   **Name:** `Lab-Firewall-Policy`
    *   **Stateful rule groups:** Crie um novo grupo de regras stateful.
        *   **Name:** `Domain-Filtering-Rules`
        *   **Capacity:** `100` (capacidade de regras)
        *   **Add Rule:**
            *   **Rule Type:** `Domain list`
            *   **Domain names:** Adicione `www.amazon.com`
            *   **Action:** `Allow`
        *   **Default action:** `Deny all` (Isso significa que apenas os domínios na lista de permissão serão permitidos; todo o resto será negado).
    *   Crie o grupo de regras e a política de firewall.
7.  Clique em **"Create firewall"**. (Pode levar vários minutos para provisionar o firewall e seus endpoints).

**Passo 4: Configurar o Roteamento para Forçar a Inspeção**
*Esta é a parte mais complexa, pois o tráfego precisa ser roteado através do endpoint do firewall.*
1.  **Rota da Sub-rede da Aplicação (`Subnet-App`):**
    *   Crie uma tabela de rotas (`App-RT`) para a `Subnet-App`.
    *   Associe-a à `Subnet-App`.
    *   Adicione uma rota `0.0.0.0/0` com o `target` sendo o **endpoint do Network Firewall** (selecione-o em `Gateway Load Balancer Endpoint`). Isso força todo o tráfego de saída da `Subnet-App` a passar pelo firewall.
2.  **Tabela de Rotas do Firewall (`Firewall-RT`):**
    *   Crie uma nova tabela de rotas, `Firewall-RT`.
    *   Associe-a à `Subnet-Firewall` (onde o endpoint do firewall reside).
    *   Adicione uma rota `0.0.0.0/0` com o `target` sendo o **NAT Gateway** (`FW-NAT-GW`). Isso garante que o tráfego inspecionado pelo firewall possa sair para a internet.
3.  **Tabela de Rotas do IGW (`FW-Public-RT`):**
    *   Na `FW-Public-RT` (a tabela de rotas da `Subnet-Public` que tem o IGW), adicione uma rota de volta para o tráfego de resposta que vem da internet e precisa voltar para a `Subnet-App` através do firewall.
    *   **Destination:** `10.40.0.0/16` (o CIDR da sua `FW-VPC`).
    *   **Target:** Selecione o **endpoint do Network Firewall** (`Gateway Load Balancer Endpoint`).

**Passo 5: Lançar a Instância e Testar**
1.  Lance uma instância EC2 (`t2.micro`, Amazon Linux 2) na `Subnet-App`. Associe um Security Group que permita SSH do seu IP local.
2.  Conecte-se a ela via SSH.
3.  A partir da instância, tente acessar os domínios:
    *   `curl -I https://www.amazon.com`
        *   **Resultado esperado:** Sucesso! O firewall inspecionou o domínio, encontrou uma regra de `Allow` e permitiu o tráfego.
    *   `curl -I https://www.google.com`
        *   **Resultado esperado:** Falha (timeout)! O firewall inspecionou o domínio, não encontrou uma regra de `Allow` e aplicou a ação padrão `Deny all`.

Este laboratório demonstra como o AWS Network Firewall pode ser usado para inspeção de tráfego avançada e filtragem de domínio, fornecendo uma camada de segurança muito mais sofisticada do que os Security Groups e NACLs sozinhos.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **VPC de Inspeção Centralizada:** Para ambientes multi-VPC, sempre use o padrão de VPC de Inspeção Centralizada com Transit Gateway. Isso simplifica o gerenciamento, reduz custos e garante que todo o tráfego seja inspecionado.
*   **Ordem das Regras:** Entenda a ordem de processamento das regras no Network Firewall: Stateless Rules -> Stateful Rules -> Default Actions. Use regras stateless para tráfego que não precisa de inspeção profunda (ex: tráfego de monitoramento).
*   **Regras Suricata:** Aproveite o poder das regras Suricata para detecção e prevenção de intrusões personalizadas. Use as regras gerenciadas da AWS para ameaças comuns.
*   **Logging e Monitoramento:** Habilite o logging do Network Firewall para o CloudWatch Logs e S3. Monitore as métricas do firewall para identificar tráfego bloqueado, ameaças detectadas e performance.
*   **Planejamento de Roteamento:** O roteamento é a parte mais crítica da implantação do Network Firewall. Certifique-se de que todas as tabelas de rotas (nas VPCs de aplicação e na VPC de inspeção) estão configuradas corretamente para forçar o tráfego através do firewall.
*   **Custo:** O Network Firewall tem um custo por hora e por GB de dados processados. Planeje sua arquitetura para otimizar o tráfego e evitar custos desnecessários.
*   **IaC para Network Firewall:** Gerencie seu Network Firewall, políticas e grupos de regras usando Infraestrutura como Código (Terraform, CloudFormation) para garantir consistência, automação e controle de versão.