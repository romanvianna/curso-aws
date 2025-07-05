# Módulo 4.2: Otimização de Custos (Cost Optimization)

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Entender os principais vetores de custo em uma arquitetura de rede da AWS.
- Analisar os custos de transferência de dados (Data Transfer) e como otimizá-los.
- Aprender a usar ferramentas como o AWS Cost Explorer para analisar e visualizar os custos da VPC.
- Aplicar estratégias de otimização, como o uso de VPC Endpoints, para reduzir custos.

---

## 1. Anatomia dos Custos de Rede na AWS (Teoria - 60 min)

Um dos pilares do AWS Well-Architected Framework é a **Otimização de Custos**. Na rede, os custos podem ser significativos e, por vezes, surpreendentes se não forem bem compreendidos. Os principais vetores de custo são:

### 1. Custo de Processamento por Hora de Serviços

Alguns componentes de rede têm um custo fixo por hora em que estão provisionados. É importante saber quais são eles para evitar deixar recursos ociosos rodando.

-   **NAT Gateway:** Você paga por cada hora que um NAT Gateway está provisionado, **independentemente de quanto tráfego ele processa**. Além disso, você paga por cada Gigabyte de dados que ele processa.
-   **VPC Interface Endpoints (PrivateLink):** Você paga por cada hora que um endpoint de interface está provisionado em cada Zona de Disponibilidade. Você também paga por GB de dados processados.
-   **Load Balancers (ALB/NLB):** Você paga por hora e também por uma unidade de medida chamada LCU (Load Balancer Capacity Unit), que é baseada em uma combinação de conexões, largura de banda e regras processadas.
-   **Conexões VPN e Direct Connect:** Têm custos por hora de conexão.

**Serviços Gratuitos:** É igualmente importante saber o que **não** tem custo por hora: VPCs, Sub-redes, Tabelas de Rotas, Internet Gateways, Virtual Private Gateways, e VPC Gateway Endpoints (para S3 e DynamoDB).

### 2. Custo de Transferência de Dados (Data Transfer)

Este é frequentemente o custo de rede mais significativo e o mais complexo de entender. A regra geral é:

**O tráfego de entrada (Inbound) para a AWS a partir da internet é geralmente gratuito.**
**O tráfego de saída (Outbound) da AWS para a internet é sempre pago.**

Vamos detalhar os cenários:

-   **Transferência de Dados DENTRO de uma Região:**
    -   **Dentro da mesma AZ:** A transferência de dados entre instâncias EC2 na **mesma** Zona de Disponibilidade, usando IPs privados, é **gratuita**.
        -   *Implicação:* Se você tem uma aplicação "falante" (ex: um servidor de aplicação e um cache Redis que trocam muitos dados), colocá-los na mesma AZ pode economizar custos, mas sacrifica a alta disponibilidade.
    -   **Entre AZs Diferentes:** A transferência de dados entre AZs diferentes na mesma região **é paga** em ambas as direções (US$ 0,01 por GB). Isso é chamado de custo de processamento inter-AZ.
        -   *Implicação:* Arquiteturas de alta disponibilidade que replicam dados entre AZs (ex: bancos de dados RDS Multi-AZ) incorrem nesses custos. O tráfego que passa por um NAT Gateway ou Load Balancer para uma instância em outra AZ também paga essa taxa.

-   **Transferência de Dados PARA a Internet (Data Transfer Out - DTO):**
    -   Este é o custo mais alto. Qualquer dado que sai da sua VPC (através de um IGW ou NAT Gateway) para a internet é cobrado por Gigabyte. O preço varia por região e diminui ligeiramente com o volume.

### Estratégias de Otimização de Custos

1.  **Use VPC Gateway Endpoints para S3 e DynamoDB:**
    -   Esta é a otimização mais importante e fácil de implementar. Se suas instâncias em sub-redes privadas se comunicam muito com o S3 ou DynamoDB, esse tráfego, por padrão, passa por um NAT Gateway. Você paga pelo processamento do NAT GW e pela transferência de dados inter-AZ (se o NAT GW estiver em uma AZ diferente).
    -   Ao criar um **Gateway Endpoint** (que é gratuito), o tráfego para o S3/DynamoDB permanece dentro da rede da AWS e não passa pelo NAT Gateway, eliminando ambos os custos.

2.  **Use VPC Interface Endpoints para outros serviços:**
    -   Para outros serviços da AWS (SQS, Kinesis, etc.), um Interface Endpoint tem um custo por hora. No entanto, se o volume de dados for alto, o custo do endpoint pode ser menor do que o custo de processamento do NAT Gateway que ele substitui. É necessário fazer as contas.

3.  **Otimize a Topologia Intra-AZ:**
    -   Para componentes com comunicação muito intensa, considere colocá-los na mesma AZ para eliminar os custos de transferência inter-AZ. Use isso com cuidado, pois afeta a resiliência.

4.  **Use o AWS Cost Explorer:**
    -   Esta é a principal ferramenta para analisar seus custos. Você pode filtrar seus custos por serviço (EC2, VPC), por tipo de uso (ex: `DataTransfer-Regional-Bytes`) e por tags. É essencial para identificar onde seus custos de rede estão sendo gerados.

---

## 2. Análise e Otimização de Custos (Prática - 60 min)

Neste laboratório, vamos usar o Cost Explorer para analisar os custos de transferência de dados e, em seguida, discutir como um Gateway Endpoint poderia otimizar um cenário comum.

### Roteiro Prático

**Parte 1: Análise com o AWS Cost Explorer**
1.  Navegue até o console do **AWS Cost Management > Cost Explorer**.
2.  Inicie o Cost Explorer se for a primeira vez.
3.  No painel à direita, em **"Filters"**, vamos detalhar os custos:
    -   **Service:** Selecione `EC2`. (A maioria dos custos de transferência de dados, mesmo os da VPC, são faturados sob o serviço EC2).
4.  Agora, vamos detalhar ainda mais por tipo de uso:
    -   No grupo de filtros, selecione **"Usage Type Group"**.
    -   Marque as caixas para os seguintes grupos:
        -   `EC2: Data Transfer - AWS In/Out` (Transferência de/para a internet)
        -   `EC2: Data Transfer - Regional` (Transferência entre AZs)
5.  Clique em **"Apply filters"**.
6.  **Análise do Gráfico:**
    -   O gráfico agora mostrará seus custos de transferência de dados ao longo do tempo, divididos por tipo.
    -   Você pode identificar qual tipo de transferência está gerando mais custos. Em muitas arquiteturas, o custo de `DataTransfer-Regional-Bytes` (entre AZs) pode ser surpreendentemente alto.

**Parte 2: Simulação de Otimização de Custos**

Vamos analisar um cenário e calcular a economia potencial.

-   **Cenário:**
    -   Você tem uma frota de instâncias EC2 em uma sub-rede privada na AZ `us-east-1a`.
    -   Elas processam e enviam **100 TB (102.400 GB)** de dados para um bucket S3 a cada mês.
    -   Para fazer isso, o tráfego passa por um NAT Gateway que está na mesma AZ (`us-east-1a`).

-   **Cálculo do Custo (Sem Otimização):**
    -   **Custo do NAT Gateway (Processamento):**
        -   Preço: US$ 0,045 por GB processado.
        -   Custo: `102.400 GB * $0.045/GB = $4.608 por mês`.
    -   **Custo de Transferência de Dados:**
        -   Como o tráfego vai para o S3 na mesma região, não há custo de DTO para a internet. O custo está no processamento do NAT GW.
    -   **Custo Total da Operação: ~$4.608/mês**

-   **Cálculo do Custo (Com Otimização):**
    -   **Ação:** Criamos um **VPC Gateway Endpoint** para o S3 na nossa VPC e o associamos à tabela de rotas da nossa sub-rede privada.
    -   **Novo Fluxo de Tráfego:** O tráfego da instância para o S3 agora flui diretamente através do endpoint, **contornando o NAT Gateway**.
    -   **Custo do Gateway Endpoint:** **$0**.
    -   **Custo de Processamento do NAT Gateway:** **$0** (para este fluxo de tráfego).
    -   **Custo de Transferência de Dados:** **$0** (o tráfego para o S3 na mesma região através de um endpoint é gratuito).
    -   **Custo Total da Operação: $0**

-   **Resultado da Otimização:**
    -   **Economia Mensal: ~$4.608**

Esta análise prática demonstra o impacto financeiro massivo que uma única otimização de arquitetura de rede, como a implementação de um Gateway Endpoint, pode ter. A otimização de custos na nuvem não é apenas sobre desligar instâncias, mas também sobre projetar fluxos de tráfego eficientes.
