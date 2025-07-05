# Módulo 1.1: Internet Gateway vs. NAT Gateway/Instance

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Compreensão dos conceitos de VPC, sub-redes (públicas e privadas) e tabelas de rotas.
*   Conhecimento básico de endereçamento IP e CIDR.
*   Acesso a uma conta AWS com permissões para criar recursos de VPC.

## Objetivos

*   Aprofundar o conhecimento sobre Network Address Translation (NAT), diferenciando NAT 1:1 (Estático) de NAT 1-para-Muitos (PAT).
*   Mapear esses conceitos para o funcionamento do Internet Gateway (NAT 1:1) e do NAT Gateway (PAT).
*   Analisar as implicações de cada solução em termos de arquitetura, performance, alta disponibilidade e custo.
*   Implementar um NAT Gateway para fornecer acesso à internet para sub-redes privadas, validando seu funcionamento.
*   Discutir casos de uso do mundo real para cada tipo de gateway.

---

## 1. A Mecânica da Tradução de Endereços de Rede (Teoria - 60 min)

Já estabelecemos que endereços IP privados (RFC 1918) não podem existir na internet. A tecnologia que faz a ponte entre o mundo privado e o público é a **Network Address Translation (NAT)**. Compreender seus diferentes tipos é crucial para entender como a AWS projeta seus gateways.

### Tipos de NAT

1.  **NAT Estático (1:1):**
    *   **Conceito:** Mapeia um endereço IP privado para um endereço IP público de forma **permanente e exclusiva**. Sempre que o IP privado `10.0.1.10` envia tráfego para a internet, ele sai com o IP público `203.0.113.5`. E toda conexão que chega ao IP público `203.0.113.5` é direcionada para o IP privado `10.0.1.10`.
    *   **Caso de Uso:** Usado quando um servidor na rede privada precisa ser acessível da internet em um endereço IP fixo e conhecido. É essencialmente uma forma de "publicar" um servidor privado.
    *   **Implementação na AWS:** O **Internet Gateway (IGW)**, em conjunto com um IP Público ou Elastic IP associado a uma instância, implementa um NAT Estático 1:1.

2.  **NAT Dinâmico:**
    *   **Conceito:** Mapeia um endereço IP privado para um endereço IP público de um **pool** de endereços públicos disponíveis. O mapeamento dura apenas o tempo da conexão. Isso é menos comum hoje em dia.

3.  **PAT (Port Address Translation) ou NAPT (Network Address Port Translation):**
    *   **Conceito:** Esta é a forma mais comum de NAT e a mais importante para este módulo. É um tipo de NAT dinâmico que permite que **muitos** endereços IP privados sejam mapeados para um **único** endereço IP público, usando as **portas** para diferenciar as conexões.
    *   **Como Funciona:** Quando várias instâncias (`10.0.2.10`, `10.0.2.11`, etc.) enviam tráfego para a internet através de um dispositivo PAT com um único IP público (`203.0.113.10`), o dispositivo PAT cria uma tabela de tradução que rastreia não apenas os IPs, mas a combinação de **IP e porta de origem**.
        *   Conexão A: `[10.0.2.10: porta 34567]` -> `[203.0.113.10: porta 61001]`
        *   Conexão B: `[10.0.2.11: porta 48999]` -> `[203.0.113.10: porta 61002]`
    *   Quando a resposta volta para `203.0.113.10` na porta `61001`, o dispositivo PAT sabe que deve encaminhá-la para `10.0.2.10`.
    *   **Caso de Uso:** É a tecnologia usada em roteadores domésticos e corporativos para permitir que centenas de dispositivos acessem a internet com um único IP público. É ideal para comunicação de **saída**.
    *   **Implementação na AWS:** O **NAT Gateway** implementa o PAT.

### Comparativo Arquitetural: IGW vs. NAT Gateway

| Característica | Internet Gateway (IGW) | NAT Gateway |
| :--- | :--- | :--- |
| **Tipo de NAT** | **NAT Estático (1:1)** | **PAT (Muitos-para-Um)** |
| **Direção do Tráfego** | **Bidirecional:** Permite tráfego de entrada e saída. | **Unidirecional (Saída):** Permite que a rede privada inicie conexões, mas bloqueia conexões iniciadas da internet. |
| **Posicionamento** | Anexado à VPC. | Provisionado em uma **sub-rede pública**. |
| **Dependência** | Nenhuma. É o gateway principal. | Depende de um IGW para encaminhar seu tráfego para a internet. |
| **IP Público** | Usa o IP Público/EIP da instância. | Requer seu próprio Elastic IP. |
| **Principal Uso** | Publicar recursos que **precisam ser acessados** da internet (servidores web, ALBs). | Permitir que recursos privados **acessem** a internet de forma segura (para atualizações, APIs). |

### E a NAT Instance?

Uma **NAT Instance** é simplesmente uma instância EC2 que você mesmo configura para realizar o PAT. Antes do serviço gerenciado NAT Gateway, esta era a única maneira. Hoje, ela é considerada uma solução legada devido às suas desvantagens:
-   **Gerenciamento:** Você é responsável por tudo (patching, hardening do SO).
-   **Disponibilidade:** É um ponto único de falha. Se a instância cair, sua rede privada perde o acesso à internet. Você precisa construir scripts complexos de failover.
-   **Performance:** A largura de banda é limitada pelo tipo da instância EC2.

O NAT Gateway gerenciado pela AWS resolve todos esses problemas, oferecendo alta disponibilidade zonal e escalabilidade de até 100 Gbps.

---

## 2. Implementação de NAT Gateway (Prática - 60 min)

Neste laboratório, vamos adicionar um NAT Gateway à nossa `Lab-VPC` para permitir que uma instância na sub-rede privada acesse a internet, validando o padrão de arquitetura PAT.

### Cenário

Nossa instância `Lab-DBServer` na sub-rede privada está completamente isolada. Vamos dar a ela a capacidade de baixar atualizações de pacotes do sistema operacional, o que requer acesso de saída à internet.

### Roteiro Prático

**Passo 1: Alocar um Elastic IP**
1.  No console da VPC, vá para **Elastic IPs** e clique em **"Allocate Elastic IP address"**.
2.  Mantenha as configurações padrão e clique em **"Allocate"**. Este será o endereço público do nosso dispositivo PAT.

**Passo 2: Criar o NAT Gateway**
1.  Vá para **NAT Gateways** e clique em **"Create NAT gateway"**.
2.  **Name:** `Lab-NAT-GW`
3.  **Subnet:** **Selecione a sub-rede PÚBLICA** (`Lab-Subnet-Public`). O NAT Gateway precisa residir na sub-rede que tem um caminho para o IGW.
4.  **Connectivity type:** `Public`.
5.  **Elastic IP allocation ID:** Selecione o Elastic IP que você alocou no passo anterior.
6.  Clique em **"Create NAT gateway"**. O provisionamento pode levar alguns minutos.

**Passo 3: Configurar o Roteamento da Sub-rede Privada**
Este é o passo crucial. Precisamos dizer à sub-rede privada para usar o NAT Gateway como sua rota padrão.
1.  Vá para **Route Tables** e selecione a tabela de rotas da sua sub-rede privada (`Lab-RT-Private`).
2.  Vá para a aba **"Routes"** e clique em **"Edit routes"**.
3.  Clique em **"Add route"**.
4.  **Destination:** `0.0.0.0/0`
5.  **Target:** Selecione **"NAT Gateway"** e depois escolha o `Lab-NAT-GW` que você criou.
6.  Clique em **"Save changes"**.

**Passo 4: Validar a Conectividade**
Agora, vamos testar se nossa instância privada pode acessar a internet.
1.  **Conecte-se ao Bastion Host:** Use SSH para se conectar ao seu `Lab-WebServer` (que está na sub-rede pública).
2.  **Pule para a Instância Privada:** A partir do `Lab-WebServer`, conecte-se ao `Lab-DBServer` usando seu **IP privado** (pode ser necessário usar `ssh-agent forwarding`).
    `ssh ec2-user@IP_PRIVADO_LAB_DBSERVER`
3.  **Teste o Acesso à Internet:**
    -   Agora você está no shell do `Lab-DBServer`. Tente atualizar os pacotes do sistema:
        ```bash
        sudo yum update -y
        ```
    -   **Resultado esperado:** Sucesso! O `yum` conseguirá se conectar aos repositórios da Amazon Linux na internet e verificar por atualizações.

4.  **Análise do Fluxo:**
    -   A instância `Lab-DBServer` (ex: `10.0.2.50`) iniciou uma conexão para um repositório na internet.
    -   A `Lab-RT-Private` direcionou o tráfego para o `Lab-NAT-GW`.
    -   O `Lab-NAT-GW` recebeu o pacote, registrou a conexão em sua tabela de tradução e trocou o IP de origem `10.0.2.50` pelo seu próprio Elastic IP público.
    -   O tráfego foi então encaminhado para o `Lab-IGW` e para a internet.
    -   A resposta voltou pelo mesmo caminho, provando que a tradução PAT funcionou como esperado.

Este laboratório demonstra a arquitetura padrão para fornecer acesso seguro à internet para camadas de back-end, um padrão fundamental em design de redes na AWS.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Use NAT Gateway em vez de NAT Instance:** Para a maioria dos casos de uso, a AWS recomenda o uso de NAT Gateways devido à sua alta disponibilidade, escalabilidade e baixo overhead de gerenciamento.
*   **Custo:** Esteja ciente dos custos associados ao NAT Gateway. Você paga por hora e por GB de dados processados. Para otimizar custos, considere agrupar recursos que precisam de acesso à internet em uma única VPC e usar um único NAT Gateway.
*   **Monitoramento:** Monitore as métricas do seu NAT Gateway no CloudWatch. A métrica `ErrorPortAllocation` é especialmente importante, pois indica que o NAT Gateway está ficando sem portas, o que pode levar a falhas de conexão.
*   **Segurança:** Embora o NAT Gateway bloqueie conexões de entrada não solicitadas, ele não substitui a necessidade de Security Groups e Network ACLs. Use essas camadas de segurança para controlar o tráfego de entrada e saída de suas instâncias.
*   **VPC Endpoints:** Para serviços da AWS que suportam VPC Endpoints (como S3 e DynamoDB), use-os em vez de um NAT Gateway. Isso mantém o tráfego na rede da AWS, melhorando a segurança e reduzindo os custos.
