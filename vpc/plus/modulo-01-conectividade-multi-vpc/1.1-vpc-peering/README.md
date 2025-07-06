# Módulo 1.1: VPC Peering

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento sólido dos conceitos de VPC, sub-redes e tabelas de rotas.
*   Familiaridade com o console da AWS e a criação de instâncias EC2.
*   Compreensão de endereçamento IP e CIDR, especialmente a importância de CIDRs não sobrepostos.

## Objetivos

*   Entender o desafio do isolamento de VPCs e os cenários que exigem conectividade privada entre elas.
*   Aprender sobre o VPC Peering como um mecanismo para conectar duas VPCs de forma privada e segura.
*   Analisar a arquitetura, o fluxo de requisição/aceitação e as limitações cruciais do VPC Peering (como a falta de roteamento transitivo).
*   Implementar uma conexão de VPC Peering entre duas VPCs e validar a conectividade privada.
*   Discutir casos de uso e as melhores práticas para o VPC Peering em ambientes de produção.

---

## 1. Conectando Ilhas de Rede (Teoria - 60 min)

Por padrão, as VPCs são **ilhas de rede logicamente isoladas**. Uma instância na VPC-A não tem absolutamente nenhuma maneira de se comunicar com uma instância na VPC-B, mesmo que ambas pertençam à mesma conta AWS na mesma região. Esse isolamento é uma característica de segurança fundamental da AWS.

No entanto, em organizações em crescimento, surgem cenários onde a comunicação entre essas ilhas é necessária:

*   **Separação por Ambiente:** Você pode ter uma VPC para desenvolvimento e outra para produção. A VPC de desenvolvimento pode precisar acessar um serviço de artefatos (como um repositório de pacotes) na VPC de produção.
*   **Separação por Unidade de Negócio:** A equipe de Marketing (VPC-MKT) pode precisar consumir uma API da equipe de Engenharia (VPC-ENG).
*   **Serviços Compartilhados:** Uma organização pode ter uma VPC dedicada a serviços compartilhados (ex: servidores de autenticação, logging, monitoramento) que precisam ser acessados por múltiplas outras VPCs.

Como conectar essas ilhas de forma privada, sem que o tráfego precise sair para a internet e voltar?

### VPC Peering: Uma Ponte Privada 1-para-1

O **VPC Peering** é um recurso de rede que permite conectar duas VPCs, permitindo que elas se comuniquem entre si usando endereços IP privados, como se estivessem na mesma rede. É uma conexão direta e privada.

*   **Como Funciona:** Ele cria uma conexão ponto-a-ponto, direta e privada entre as duas VPCs. O tráfego que usa uma conexão de peering permanece na rede global e privada da Amazon, nunca atravessando a internet pública. Isso significa maior segurança e menor latência.

*   **Arquitetura e Configuração:**
    1.  **Requisição e Aceitação:** O processo é iniciado pelo "solicitante" (VPC-A) que envia um pedido de peering para o "aceitante" (VPC-B). A conexão só se torna ativa depois que o proprietário da VPC-B **aceita** o pedido. Isso impede conexões indesejadas e exige coordenação entre as partes.
    2.  **Atualização das Tabelas de Rotas:** Apenas criar a conexão não é suficiente. Para que o tráfego flua, você deve **manualmente atualizar as tabelas de rotas** em **ambas** as VPCs. 
        *   Na VPC-A, você adiciona uma rota com o destino sendo o bloco CIDR da VPC-B, e o `target` sendo a conexão de peering (`pcx-xxxxxxxx`).
        *   Na VPC-B, você adiciona uma rota com o destino sendo o bloco CIDR da VPC-A, e o `target` sendo a mesma conexão de peering.
    3.  **Atualização dos Security Groups:** Os Security Groups em cada VPC devem ser atualizados para permitir o tráfego vindo do bloco CIDR (ou de um Security Group específico, se for peering na mesma conta) da VPC pareada. Isso garante que o tráfego seja permitido em nível de instância.

### Limitações Cruciais do VPC Peering

O VPC Peering é simples e eficaz para casos de uso específicos, mas tem limitações importantes que o tornam inadequado para topologias de rede complexas ou em larga escala:

1.  **Não há Roteamento Transitivo:** Esta é a limitação mais importante. Se a VPC-A está pareada com a VPC-B, e a VPC-B está pareada com a VPC-C, a VPC-A **NÃO** pode se comunicar com a VPC-C através da VPC-B. O tráfego não pode "pular" de uma conexão de peering para outra. Para que A e C se comuniquem, elas precisam de sua própria conexão de peering direta.

2.  **Malha de Conexões (Mesh Topology):** A falta de transitividade leva a um problema de escala. Se você tem `n` VPCs e todas precisam se comunicar entre si, você não precisa de `n` conexões. Você precisa de uma **malha completa** de conexões diretas. O número de conexões necessárias é `n * (n-1) / 2`. Para 5 VPCs, são 10 conexões. Para 10 VPCs, são 45 conexões. Gerenciar as tabelas de rotas para essa "malha de peering" se torna um pesadelo operacional e propenso a erros.

3.  **CIDRs Sobrepostos:** As VPCs que você deseja parear **não podem ter blocos CIDR sobrepostos**. Se a VPC-A e a VPC-B usam `10.0.0.0/16`, o roteador não saberia para onde enviar o tráfego destinado a um IP nessa faixa. Isso exige um planejamento de endereçamento IP cuidadoso em toda a organização, especialmente em ambientes multi-conta.

**Conclusão:** O VPC Peering é uma excelente solução para conectar um pequeno número de VPCs em uma topologia simples e direta. Para conectar muitas VPCs de forma escalável e gerenciar o roteamento de forma centralizada, uma solução como o **Transit Gateway** (que veremos no próximo módulo) é necessária.

## 2. Implementação de VPC Peering (Prática - 60 min)

Neste laboratório, vamos criar duas VPCs e conectá-las com uma conexão de peering, validando a comunicação privada entre elas. Isso simula um cenário comum de integração entre equipes ou ambientes.

### Cenário: Integração entre Equipes de Desenvolvimento e Dados

Uma empresa tem duas equipes: a equipe de Desenvolvimento (que gerencia a `VPC-Dev`) e a equipe de Dados (que gerencia a `VPC-Data`). A `VPC-Dev` precisa acessar um servidor de relatórios na `VPC-Data` usando IPs privados. As VPCs têm CIDRs não sobrepostos.

*   **VPC-Dev:** `10.10.0.0/16`, com uma instância EC2 (`Instance-Dev`).
*   **VPC-Data:** `10.20.0.0/16`, com uma instância EC2 (`Instance-Data`).
*   **Objetivo:** Fazer ping e SSH da `Instance-Dev` para a `Instance-Data` usando seus IPs privados.

### Roteiro Prático

**Passo 1: Criar as Duas VPCs e suas Instâncias**
1.  Usando o console ou um script (como os do Módulo 3.1), crie duas VPCs separadas:
    *   `VPC-Dev` com CIDR `10.10.0.0/16` e uma sub-rede pública `10.10.1.0/24`.
    *   `VPC-Data` com CIDR `10.20.0.0/16` e uma sub-rede pública `10.20.1.0/24`.
2.  Lance uma instância EC2 (`t2.micro`, Amazon Linux 2) em cada VPC (`Instance-Dev` na `VPC-Dev` e `Instance-Data` na `VPC-Data`). Por simplicidade, você pode colocá-las em sub-redes públicas com IPs públicos para que possamos acessá-las inicialmente via SSH do seu computador.
3.  Crie um Security Group para cada instância (`SG-Dev` e `SG-Data`). Por enquanto, apenas permita SSH do seu IP local.

**Passo 2: Criar a Conexão de Peering**
1.  Navegue até **VPC > Peering Connections > Create peering connection**.
2.  **Name:** `Dev-to-Data-Peering`
3.  **VPC ID (Requester):** Selecione `VPC-Dev`.
4.  **VPC ID (Accepter):** Selecione `VPC-Data`.
5.  Clique em **"Create peering connection"**.
6.  **Aceitar a Conexão:** Selecione a conexão recém-criada (que estará no estado `pending-acceptance`). Vá em **Actions > Accept request**.
7.  O estado da conexão mudará para `active`.

**Passo 3: Atualizar as Tabelas de Rotas**
*A conexão está ativa, mas o tráfego não fluirá até que os mapas de roteamento sejam atualizados em ambas as VPCs.*
1.  Vá para **Route Tables**. Encontre a tabela de rotas associada à sub-rede da `Instance-Dev` (ex: `VPC-Dev-Public-RT`).
2.  Edite suas rotas e adicione uma nova:
    *   **Destination:** `10.20.0.0/16` (o CIDR da `VPC-Data`).
    *   **Target:** Selecione **"Peering Connection"** e escolha a `Dev-to-Data-Peering` (`pcx-xxxxxxxx`).
3.  Agora, encontre a tabela de rotas associada à sub-rede da `Instance-Data` (ex: `VPC-Data-Public-RT`).
4.  Edite suas rotas e adicione a rota de volta:
    *   **Destination:** `10.10.0.0/16` (o CIDR da `VPC-Dev`).
    *   **Target:** Selecione **"Peering Connection"** e escolha a `Dev-to-Data-Peering` (`pcx-xxxxxxxx`).

**Passo 4: Atualizar os Security Groups**
Para permitir o tráfego entre as instâncias, os Security Groups também precisam ser atualizados.
1.  Vá para o Security Group da `Instance-Data` (`SG-Data`).
2.  Edite as regras de entrada e adicione uma regra para permitir a comunicação da `VPC-Dev`:
    *   **Type:** `All ICMP - IPv4` (para permitir o ping).
    *   **Source:** `10.10.0.0/16` (o CIDR da `VPC-Dev`).
3.  Adicione outra regra para permitir o SSH:
    *   **Type:** `SSH (22)`
    *   **Source:** `10.10.0.0/16`.

**Passo 5: Validar a Conectividade**
1.  Conecte-se via SSH à `Instance-Dev` usando seu IP público.
2.  A partir do shell da `Instance-Dev`, tente se conectar à `Instance-Data` usando seu **IP privado**.
    *   Pegue o IP privado da `Instance-Data` no console (ex: `10.20.1.x`).
    *   **Teste de Ping:**
        `ping -c 3 IP_PRIVADO_DA_INSTANCE_DATA`
        **Resultado esperado:** Sucesso! O ping deve funcionar.
    *   **Teste de SSH:**
        `ssh ec2-user@IP_PRIVADO_DA_INSTANCE_DATA`
        **Resultado esperado:** A conexão SSH deve ser estabelecida (pode pedir confirmação da chave do host na primeira vez).

Você estabeleceu com sucesso uma ponte privada entre duas VPCs isoladas, permitindo que os recursos se comuniquem de forma segura usando seus endereços IP privados, sem que o tráfego jamais saia da rede da AWS.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Planejamento de CIDR:** O planejamento cuidadoso dos blocos CIDR é fundamental. Certifique-se de que as VPCs que você pretende parear **NUNCA** tenham CIDRs sobrepostos. Isso é um requisito técnico e uma falha comum.
*   **Roteamento Bidirecional:** Lembre-se que o VPC Peering exige que as tabelas de rotas de **ambas** as VPCs sejam atualizadas para que o tráfego flua em ambas as direções.
*   **Security Groups:** Não se esqueça de ajustar os Security Groups nas instâncias de destino para permitir o tráfego da VPC pareada (usando o CIDR da VPC remota como origem).
*   **Não Transitivo:** Reforce a regra de que o VPC Peering não é transitivo. Se você precisa de conectividade entre muitas VPCs, o Transit Gateway é a solução mais escalável.
*   **Monitoramento:** Monitore as métricas da conexão de peering no CloudWatch (ex: `BytesIn`, `BytesOut`) e as rotas nas tabelas de rotas para garantir que a conectividade esteja funcionando como esperado.
*   **IaC para Peering:** Gerencie suas conexões de VPC Peering e as atualizações de tabelas de rotas usando Infraestrutura como Código (Terraform, CloudFormation) para garantir consistência e automação.
*   **Peering Inter-região:** O VPC Peering pode ser estabelecido entre VPCs em diferentes regiões da AWS. O tráfego ainda permanece na rede global da AWS, mas incorre em custos de transferência de dados inter-região.