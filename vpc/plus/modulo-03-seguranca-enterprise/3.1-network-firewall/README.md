# Módulo 3.1: AWS Network Firewall

**Tempo de Aula:** 90 minutos de teoria, 90 minutos de prática

## Objetivos

- Entender as limitações dos Security Groups e NACLs para inspeção de tráfego avançada.
- Aprender sobre firewalls de próxima geração (NGFW) e sistemas de prevenção de intrusão (IPS).
- Posicionar o AWS Network Firewall como um serviço de firewall de rede gerenciado e stateful.
- Implementar o Network Firewall em uma VPC de inspeção para filtrar o tráfego de forma centralizada.

---

## 1. Inspeção de Tráfego de Rede Avançada (Teoria - 90 min)

Até agora, nossas ferramentas de firewall (Security Groups e NACLs) operam principalmente nas **Camadas 3 (Rede) e 4 (Transporte)** do modelo OSI. Elas tomam decisões com base em endereços IP e portas. Elas são excelentes para controle de acesso, mas não conseguem inspecionar o **conteúdo** do tráfego.

Elas não conseguem responder a perguntas como:
-   "Este tráfego na porta 80 é uma requisição HTTP legítima ou é um ataque de SQL Injection sendo tunelado por essa porta?"
-   "Este download de arquivo contém um malware conhecido?"
-   "Um servidor interno está tentando se comunicar com um domínio conhecido de comando e controle (C2) de botnets?"

Para responder a essas perguntas, precisamos de um **Firewall de Próxima Geração (NGFW)**.

### O que é um NGFW?

Um NGFW combina as funcionalidades de um firewall tradicional com recursos de segurança mais avançados:

-   **Inspeção Profunda de Pacotes (DPI - Deep Packet Inspection):** A capacidade de examinar o conteúdo real (o payload) dos pacotes, não apenas seus cabeçalhos.
-   **Sistema de Prevenção de Intrusão (IPS - Intrusion Prevention System):** Usa um banco de dados de assinaturas de ataques conhecidos para identificar e bloquear tráfego malicioso em tempo real.
-   **Filtragem de URL/Domínio:** Bloqueia o acesso a sites ou domínios com base em sua categoria (ex: malware, phishing, redes sociais) ou em listas de reputação.
-   **Prevenção de Perda de Dados (DLP - Data Loss Prevention):** Pode inspecionar o tráfego de saída para detectar e bloquear a exfiltração de dados sensíveis (ex: números de cartão de crédito).

### AWS Network Firewall: Um NGFW Gerenciado

O **AWS Network Firewall** é um serviço gerenciado que facilita a implantação de proteções de rede essenciais para todas as suas VPCs. Ele fornece a funcionalidade de um NGFW/IPS sem a necessidade de implantar e gerenciar appliances de firewall de terceiros.

**Componentes do Network Firewall:**

1.  **Política de Firewall (Firewall Policy):** O contêiner de mais alto nível. Ele define o comportamento geral do firewall, agrupando grupos de regras stateful e stateless.

2.  **Grupos de Regras Stateless:**
    -   Similares às NACLs. Processam pacotes com base em IP, porta e protocolo. São avaliadas primeiro pela sua velocidade. A principal função é permitir ou negar tráfego de forma rápida ou passá-lo para o motor de regras stateful.

3.  **Grupos de Regras Stateful:**
    -   Este é o coração do serviço. O motor stateful inspeciona o tráfego no contexto de sua conexão.
    -   **Regras de Domínio:** Permitem ou negam o tráfego com base no nome de domínio (FQDN) solicitado (ex: `deny *.example.com`).
    -   **Regras de Assinatura IPS:** O Network Firewall suporta regras escritas na sintaxe do **Suricata**, um popular motor de IPS de código aberto. A AWS fornece grupos de regras gerenciadas para ameaças conhecidas (malware, botnets, etc.), e você pode escrever as suas próprias.

### Arquitetura de Implantação: VPC de Inspeção Centralizada

Para evitar a implantação de um firewall em cada VPC (o que seria caro e complexo), o padrão de arquitetura recomendado é criar uma **VPC de Inspeção** centralizada.

-   **Como Funciona:**
    1.  Você cria uma VPC dedicada (`Inspection-VPC`).
    2.  Você implanta os **endpoints do Network Firewall** em sub-redes dentro desta VPC (um endpoint por AZ para alta disponibilidade).
    3.  Você usa um **Transit Gateway** para rotear o tráfego de suas VPCs de aplicação (spokes) para a Inspection-VPC antes que ele vá para a internet ou para outras VPCs.
    4.  Dentro da Inspection-VPC, tabelas de rotas inteligentes forçam o tráfego a passar pelo endpoint do firewall para ser inspecionado.

-   **Fluxo de Tráfego (Saída para a Internet):**
    1.  Instância na VPC-A (Spoke) envia tráfego para a internet.
    2.  A tabela de rotas da VPC-A envia todo o tráfego (`0.0.0.0/0`) para o Transit Gateway.
    3.  O TGW consulta sua tabela de rotas, que direciona o tráfego para o anexo da `Inspection-VPC`.
    4.  O tráfego chega à `Inspection-VPC`. A tabela de rotas do anexo do TGW o envia para o **endpoint do Network Firewall**.
    5.  O firewall inspeciona o tráfego. Se for permitido, ele o envia para uma sub-rede pública na `Inspection-VPC` que contém um NAT Gateway.
    6.  O NAT Gateway envia o tráfego para o Internet Gateway e para a internet.

Esta arquitetura centraliza a inspeção, garantindo que todo o tráfego de e para suas VPCs seja filtrado por um único ponto de controle, simplificando o gerenciamento e a aplicação de políticas.

---

## 2. Implementação do Network Firewall (Prática - 90 min)

Neste laboratório, vamos configurar uma arquitetura simplificada para demonstrar o poder de filtragem de domínio do Network Firewall.

### Cenário

-   Temos uma VPC com uma sub-rede pública e uma instância EC2.
-   **Objetivo:** Usar o Network Firewall para permitir que a instância acesse `www.amazon.com`, mas bloquear explicitamente o acesso a `www.google.com`.

### Roteiro Prático

**Passo 1: Criar a VPC e Sub-redes**
1.  Crie uma VPC (`FW-VPC`) com CIDR `10.40.0.0/16`.
2.  Crie três sub-redes nesta VPC:
    -   `Subnet-App` (onde nossa instância viverá): `10.40.1.0/24`
    -   `Subnet-Firewall` (onde o endpoint do FW viverá): `10.40.2.0/24`
    -   `Subnet-Public` (com um IGW e NAT GW): `10.40.3.0/24`

**Passo 2: Criar e Configurar o Network Firewall**
1.  Navegue até **VPC > Network Firewall > Firewalls > Create firewall**.
2.  **Name:** `Lab-Firewall`
3.  **VPC:** Selecione sua `FW-VPC`.
4.  **Availability Zones:** Selecione a AZ onde você criou suas sub-redes e, para a sub-rede do firewall, escolha a `Subnet-Firewall`.
5.  **Firewall policy:** Selecione **"Create and associate a new firewall policy"**.
6.  **Na criação da política:**
    -   **Name:** `Lab-Firewall-Policy`
    -   **Stateful rule groups:** Crie um novo grupo de regras stateful.
        -   **Name:** `Domain-Filtering-Rules`
        -   **Capacity:** `100`
        -   **Add Rule:**
            -   **Rule Type:** `Domain list`
            -   **Domain names:** Adicione `www.amazon.com`
            -   **Action:** `Allow`
        -   **Default action:** `Deny all` (Isso significa que apenas os domínios na lista de permissão serão permitidos).
    -   Crie o grupo de regras e a política de firewall.
7.  Clique em **"Create firewall"**. (Pode levar vários minutos para provisionar).

**Passo 3: Configurar o Roteamento para Forçar a Inspeção**
*Esta é a parte mais complexa.*
1.  **Rota da Sub-rede da Aplicação:**
    -   Vá para a tabela de rotas da `Subnet-App`.
    -   Adicione uma rota `0.0.0.0/0` com o `target` sendo o **endpoint do Network Firewall** (selecione-o em `Gateway Load Balancer Endpoint`).
2.  **Tabela de Rotas do Firewall:**
    -   Crie uma nova tabela de rotas, `Firewall-RT`.
    -   Associe-a à `Subnet-Firewall`.
    -   Adicione uma rota `0.0.0.0/0` com o `target` sendo um **NAT Gateway** (que você deve criar na `Subnet-Public`).
3.  **Tabela de Rotas do IGW:**
    -   Na tabela de rotas associada à `Subnet-Public` (que tem o IGW), adicione uma rota de volta para o tráfego de resposta, apontando para o endpoint do firewall.

**Passo 4: Lançar a Instância e Testar**
1.  Lance uma instância EC2 na `Subnet-App`.
2.  Conecte-se a ela (você pode precisar de um bastion host ou de uma rota temporária para o IGW para o acesso inicial).
3.  A partir da instância, tente acessar os domínios:
    -   `curl -I https://www.amazon.com`
        -   **Resultado esperado:** Sucesso! O firewall inspecionou o domínio, encontrou uma regra de `Allow` e permitiu o tráfego.
    -   `curl -I https://www.google.com`
        -   **Resultado esperado:** Falha (timeout)! O firewall inspecionou o domínio, não encontrou uma regra de `Allow` e aplicou a ação padrão `Deny all`.

Este laboratório demonstra como o AWS Network Firewall pode ser usado para inspeção de tráfego avançada e filtragem de domínio, fornecendo uma camada de segurança muito mais sofisticada do que os Security Groups e NACLs sozinhos.
