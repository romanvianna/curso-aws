# Módulo 1.1: VPC Peering

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Entender o desafio do isolamento de VPCs e os cenários que exigem conectividade entre elas.
- Aprender sobre o VPC Peering como um mecanismo para conectar duas VPCs de forma privada.
- Analisar a arquitetura, limitações (como a falta de roteamento transitivo) e o fluxo de requisição/aceitação do VPC Peering.
- Implementar uma conexão de VPC Peering entre duas VPCs e validar a conectividade privada.

---

## 1. Conectando Ilhas de Rede (Teoria - 60 min)

Por padrão, as VPCs são **ilhas de rede logicamente isoladas**. Uma instância na VPC-A não tem absolutamente nenhuma maneira de se comunicar com uma instância na VPC-B, mesmo que ambas pertençam à mesma conta AWS na mesma região. Esse isolamento é uma característica de segurança fundamental.

No entanto, em organizações em crescimento, surgem cenários onde a comunicação entre essas ilhas é necessária:
-   **Separação por Ambiente:** Você pode ter uma VPC para desenvolvimento e outra para produção. A VPC de desenvolvimento pode precisar acessar um serviço de artefatos (como um repositório de pacotes) na VPC de produção.
-   **Separação por Unidade de Negócio:** A equipe de Marketing (VPC-MKT) pode precisar consumir uma API da equipe de Engenharia (VPC-ENG).
-   **Serviços Compartilhados:** Uma organização pode ter uma VPC dedicada a serviços compartilhados (ex: servidores de autenticação, logging, monitoramento) que precisam ser acessados por múltiplas outras VPCs.

Como conectar essas ilhas de forma privada, sem que o tráfego precise sair para a internet e voltar?

### VPC Peering: Uma Ponte Privada 1-para-1

O **VPC Peering** é um recurso de rede que permite conectar duas VPCs, permitindo que elas se comuniquem entre si usando endereços IP privados, como se estivessem na mesma rede. 

-   **Como Funciona:** Ele cria uma conexão ponto-a-ponto, direta e privada entre as duas VPCs. O tráfego que usa uma conexão de peering permanece na rede global e privada da Amazon, nunca atravessando a internet pública.

-   **Arquitetura:**
    1.  **Requisição e Aceitação:** O processo é iniciado pelo "solicitante" (VPC-A) que envia um pedido de peering para o "aceitante" (VPC-B). A conexão só se torna ativa depois que o proprietário da VPC-B **aceita** o pedido. Isso impede conexões indesejadas.
    2.  **Atualização das Tabelas de Rotas:** Apenas criar a conexão não é suficiente. Para que o tráfego flua, você deve **manualmente atualizar as tabelas de rotas** em **ambas** as VPCs. 
        -   Na VPC-A, você adiciona uma rota com o destino sendo o bloco CIDR da VPC-B, e o `target` sendo a conexão de peering (`pcx-xxxxxxxx`).
        -   Na VPC-B, você adiciona uma rota com o destino sendo o bloco CIDR da VPC-A, e o `target` sendo a mesma conexão de peering.
    3.  **Atualização dos Security Groups:** Os Security Groups em cada VPC devem ser atualizados para permitir o tráfego vindo do bloco CIDR (ou de um Security Group específico, se for peering na mesma conta) da VPC pareada.

### Limitações Cruciais do VPC Peering

O VPC Peering é simples e eficaz, mas tem limitações importantes que o tornam inadequado para topologias de rede complexas:

1.  **Não há Roteamento Transitivo:** Esta é a limitação mais importante. Se a VPC-A está pareada com a VPC-B, e a VPC-B está pareada com a VPC-C, a VPC-A **NÃO** pode se comunicar com a VPC-C através da VPC-B. O tráfego não pode "pular" de uma conexão de peering para outra. Para que A e C se comuniquem, elas precisam de sua própria conexão de peering direta.

2.  **Malha de Conexões (Mesh Topology):** A falta de transitividade leva a um problema de escala. Se você tem 5 VPCs e todas precisam se comunicar entre si, você não precisa de 5 conexões. Você precisa de uma **malha completa** de conexões diretas. O número de conexões necessárias é `n * (n-1) / 2`. Para 5 VPCs, são 10 conexões. Para 10 VPCs, são 45 conexões. Gerenciar as tabelas de rotas para essa "malha de peering" se torna um pesadelo operacional.

3.  **CIDRs Sobrepostos:** As VPCs que você deseja parear **não podem ter blocos CIDR sobrepostos**. Se a VPC-A e a VPC-B usam `10.0.0.0/16`, o roteador não saberia para onde enviar o tráfego destinado a um IP nessa faixa. Isso exige um planejamento de endereçamento IP cuidadoso em toda a organização.

**Conclusão:** O VPC Peering é uma excelente solução para conectar um pequeno número de VPCs em uma topologia simples. Para conectar muitas VPCs de forma escalável, uma solução centralizada como o **Transit Gateway** (que veremos a seguir) é necessária.

---

## 2. Implementação de VPC Peering (Prática - 60 min)

Neste laboratório, vamos criar duas VPCs e conectá-las com uma conexão de peering, validando a comunicação privada entre elas.

### Cenário

-   **VPC-A:** `10.10.0.0/16`, com uma instância em uma sub-rede.
-   **VPC-B:** `10.20.0.0/16`, com uma instância em uma sub-rede.
-   **Objetivo:** Fazer ping e SSH da instância na VPC-A para a instância na VPC-B usando seus IPs privados.

### Roteiro Prático

**Passo 1: Criar as Duas VPCs e suas Instâncias**
1.  Usando o console ou um script, crie duas VPCs separadas:
    -   `VPC-A` com CIDR `10.10.0.0/16` e uma sub-rede `10.10.1.0/24`.
    -   `VPC-B` com CIDR `10.20.0.0/16` e uma sub-rede `10.20.1.0/24`.
2.  Lance uma instância EC2 em cada VPC (`Instance-A` e `Instance-B`). Por simplicidade, você pode colocá-las em sub-redes públicas com IPs públicos para que possamos acessá-las inicialmente.
3.  Crie um Security Group para cada instância (`SG-A` e `SG-B`). Por enquanto, apenas permita SSH do seu IP.

**Passo 2: Criar a Conexão de Peering**
1.  Navegue até **VPC > Peering Connections > Create peering connection**.
2.  **Name:** `A-to-B-Peering`
3.  **VPC ID (Requester):** Selecione `VPC-A`.
4.  **VPC ID (Accepter):** Selecione `VPC-B`.
5.  Clique em **"Create peering connection"**.
6.  **Aceitar a Conexão:** Selecione a conexão recém-criada (que está no estado `pending-acceptance`). Vá em **Actions > Accept request**.
7.  O estado da conexão mudará para `active`.

**Passo 3: Atualizar as Tabelas de Rotas**
*A conexão está ativa, mas o tráfego não fluirá até que os mapas sejam atualizados.*
1.  Vá para **Route Tables**. Encontre a tabela de rotas associada à sub-rede da `Instance-A`.
2.  Edite suas rotas e adicione uma nova:
    -   **Destination:** `10.20.0.0/16` (o CIDR da VPC-B).
    -   **Target:** Selecione **"Peering Connection"** e escolha a `A-to-B-Peering`.
3.  Agora, encontre a tabela de rotas associada à sub-rede da `Instance-B`.
4.  Edite suas rotas e adicione a rota de volta:
    -   **Destination:** `10.10.0.0/16` (o CIDR da VPC-A).
    -   **Target:** Selecione **"Peering Connection"** e escolha a `A-to-B-Peering`.

**Passo 4: Atualizar os Security Groups**
1.  Vá para o Security Group da `Instance-B` (`SG-B`).
2.  Edite as regras de entrada e adicione uma regra para permitir a comunicação da VPC-A:
    -   **Type:** `All ICMP - IPv4` (para permitir o ping).
    -   **Source:** `10.10.0.0/16` (o CIDR da VPC-A).
3.  Adicione outra regra para permitir o SSH:
    -   **Type:** `SSH (22)`
    -   **Source:** `10.10.0.0/16`.

**Passo 5: Validar a Conectividade**
1.  Conecte-se via SSH à `Instance-A` usando seu IP público.
2.  A partir do shell da `Instance-A`, tente se conectar à `Instance-B` usando seu **IP privado**.
    -   Pegue o IP privado da `Instance-B` no console (ex: `10.20.1.x`).
    -   **Teste de Ping:**
        `ping -c 3 IP_PRIVADO_DA_INSTANCE_B`
        **Resultado esperado:** Sucesso!
    -   **Teste de SSH:**
        `ssh ec2-user@IP_PRIVADO_DA_INSTANCE_B`
        **Resultado esperado:** A conexão deve ser estabelecida (pode pedir confirmação da chave do host).

Você estabeleceu com sucesso uma ponte privada entre duas VPCs isoladas, permitindo que os recursos se comuniquem de forma segura usando seus endereços IP privados, sem que o tráfego jamais saia da rede da AWS.
