# Módulo 1.2: Transit Gateway

**Tempo de Aula:** 90 minutos de teoria, 90 minutos de prática

## Objetivos

- Entender o conceito de uma topologia de rede Hub-and-Spoke.
- Posicionar o Transit Gateway como um roteador de nuvem centralizado que permite uma arquitetura Hub-and-Spoke.
- Analisar os componentes do Transit Gateway: anexos, tabelas de rotas e propagações.
- Implementar um Transit Gateway para conectar múltiplas VPCs de forma escalável, superando as limitações do VPC Peering.

---

## 1. Topologia de Rede Hub-and-Spoke (Teoria - 90 min)

### O Problema da Malha de Peering

Como vimos, o VPC Peering não é transitivo. Isso significa que para conectar múltiplas VPCs de forma que todas possam se comunicar entre si, precisamos criar uma **malha completa (full mesh)** de conexões de peering. 

-   Para 3 VPCs, são 3 conexões.
-   Para 4 VPCs, são 6 conexões.
-   Para 10 VPCs, são 45 conexões.

Essa abordagem não escala. Gerenciar dezenas ou centenas de conexões de peering e suas respectivas entradas em tabelas de rotas é um pesadelo operacional, propenso a erros e extremamente complexo.

### A Solução: O Modelo Hub-and-Spoke

A solução para este problema de escala é uma topologia de rede clássica chamada **Hub-and-Spoke**. 

-   **Conceito:** Em vez de conectar cada local diretamente a todos os outros, você estabelece um **hub central**. Todos os locais periféricos (os **spokes**) se conectam apenas ao hub central. A comunicação entre dois spokes passa **através** do hub.
-   **Vantagens:**
    -   **Simplicidade:** Cada spoke só precisa gerenciar uma única conexão (para o hub).
    -   **Escalabilidade:** Adicionar um novo spoke (uma nova VPC) é fácil. Você simplesmente o conecta ao hub, e ele ganha automaticamente a capacidade de se comunicar com todos os outros spokes.
    -   **Controle Centralizado:** O hub se torna um ponto central para monitoramento, segurança e aplicação de políticas de roteamento.

### AWS Transit Gateway: O Hub da sua Nuvem

O **AWS Transit Gateway (TGW)** é um serviço gerenciado que atua como um **roteador de nuvem regional e centralizado**, permitindo que você implemente uma arquitetura Hub-and-Spoke na AWS.

-   **Como Funciona:** O TGW atua como um hub altamente escalável. Você anexa suas VPCs (e também suas conexões on-premises, como VPNs e Direct Connect) ao TGW. O TGW então facilita o roteamento entre todos os anexos.

### Componentes do Transit Gateway

1.  **O Transit Gateway em si:** O recurso central que atua como o roteador.

2.  **Anexos (Attachments):** Uma conexão de uma rede (como uma VPC ou uma VPN) ao TGW. Quando você anexa uma VPC, você deve especificar em quais sub-redes o TGW deve criar uma **interface de rede (ENI)**. O TGW usa essas ENIs para rotear o tráfego de e para a VPC.

3.  **Tabelas de Rotas do TGW:** Esta é a parte mais poderosa e flexível. O TGW tem sua **própria** tabela de rotas, separada das tabelas de rotas das VPCs.
    -   Esta tabela determina como o tráfego é roteado **dentro** do TGW, entre os diferentes anexos.
    -   Por padrão, o TGW vem com uma tabela de rotas que tem uma rota **propagada** de cada anexo. Isso significa que, por padrão, qualquer anexo pode rotear para qualquer outro anexo (comunicação total).
    -   Você pode criar múltiplas tabelas de rotas no TGW para criar domínios de roteamento isolados. Por exemplo, uma tabela de rotas para VPCs de produção e outra para VPCs de desenvolvimento, impedindo a comunicação entre elas.

4.  **Propagações:** Uma propagação é uma regra que diz ao TGW para aprender automaticamente as rotas de um anexo e adicioná-las a uma tabela de rotas do TGW. Isso simplifica o gerenciamento.

5.  **Associações:** Uma associação vincula um anexo a uma tabela de rotas do TGW. É isso que determina qual "mapa" um anexo usará para tomar suas decisões de roteamento.

### Fluxo de Tráfego com TGW

1.  Uma instância na VPC-A (Spoke A) envia um pacote para uma instância na VPC-B (Spoke B).
2.  A **tabela de rotas da sub-rede na VPC-A** tem uma rota para o CIDR da VPC-B, com o `target` sendo o **Transit Gateway**.
3.  O tráfego é enviado para a ENI do TGW na VPC-A.
4.  O TGW recebe o pacote e consulta sua **tabela de rotas interna**. Ele encontra uma rota para o CIDR da VPC-B, que aponta para o **anexo da VPC-B**.
5.  O TGW encaminha o pacote através da ENI do TGW na VPC-B.
6.  O pacote chega à instância de destino na VPC-B.

O TGW resolve o problema da transitividade e da malha de peering, fornecendo uma solução de conectividade de rede centralizada, escalável e gerenciável para ambientes de nuvem complexos.

---

## 2. Implementação de Transit Gateway (Prática - 90 min)

Neste laboratório, vamos conectar três VPCs usando um Transit Gateway, demonstrando como ele simplifica a conectividade em escala.

### Cenário

-   **VPC-A:** `10.10.0.0/16`
-   **VPC-B:** `10.20.0.0/16`
-   **VPC-C:** `10.30.0.0/16`
-   **Objetivo:** Permitir que instâncias em cada VPC se comuniquem com as instâncias nas outras duas VPCs, passando pelo TGW.

### Roteiro Prático

**Passo 1: Criar as VPCs e Instâncias**
1.  Crie três VPCs com os CIDRs acima. Em cada uma, crie uma sub-rede e lance uma instância EC2.

**Passo 2: Criar o Transit Gateway**
1.  Navegue até **VPC > Transit Gateways > Create transit gateway**.
2.  **Name tag:** `Lab-TGW`
3.  Deixe as outras opções como padrão (ex: a criação da tabela de rotas padrão e a propagação automática estarão habilitadas). Clique em **"Create transit gateway"**. (Pode levar alguns minutos para provisionar).

**Passo 3: Anexar as VPCs ao TGW**
1.  Vá para **Transit gateway attachments > Create transit gateway attachment**.
2.  **Anexo A:**
    -   **Transit gateway ID:** Selecione seu `Lab-TGW`.
    -   **Attachment type:** `VPC`.
    -   **VPC ID:** Selecione `VPC-A`.
    -   **Subnet IDs:** Selecione a sub-rede dentro da VPC-A onde a ENI do TGW será criada.
    -   Clique em **"Create attachment"**.
3.  **Repita o processo** para criar anexos para a `VPC-B` e a `VPC-C`.

**Passo 4: Verificar a Tabela de Rotas do TGW**
1.  Vá para **Transit gateway route tables**. Selecione a tabela de rotas padrão do seu `Lab-TGW`.
2.  Vá para a aba **"Routes"**. Você deve ver três rotas que foram **propagadas** automaticamente a partir dos seus três anexos. O TGW agora sabe como chegar a cada uma das VPCs.

**Passo 5: Atualizar as Tabelas de Rotas das VPCs**
*Este é o passo final e crucial. Cada VPC precisa saber como enviar tráfego para as outras VPCs através do TGW.*
1.  **VPC-A:**
    -   Vá para a tabela de rotas da sub-rede na VPC-A.
    -   Adicione **duas** rotas:
        -   `Destination: 10.20.0.0/16` (VPC-B) -> `Target: Transit Gateway`
        -   `Destination: 10.30.0.0/16` (VPC-C) -> `Target: Transit Gateway`
    -   *Alternativa:* Você pode adicionar uma única rota agregada, como `10.0.0.0/8`, que engloba todas as suas VPCs, e apontá-la para o TGW.

2.  **VPC-B:**
    -   Vá para a tabela de rotas da sub-rede na VPC-B.
    -   Adicione rotas para `10.10.0.0/16` (VPC-A) e `10.30.0.0/16` (VPC-C), ambas apontando para o TGW.

3.  **VPC-C:**
    -   Vá para a tabela de rotas da sub-rede na VPC-C.
    -   Adicione rotas para `10.10.0.0/16` (VPC-A) e `10.20.0.0/16` (VPC-B), ambas apontando para o TGW.

**Passo 6: Atualizar os Security Groups**
1.  Para cada uma das três instâncias, modifique seu Security Group para permitir tráfego (ex: ICMP e SSH) dos blocos CIDR das outras duas VPCs.

**Passo 7: Validar a Conectividade**
1.  Conecte-se via SSH à `Instance-A`.
2.  A partir dela, faça ping nos **IPs privados** da `Instance-B` e da `Instance-C`.
3.  Ambos os pings devem funcionar.
4.  Repita o teste a partir da `Instance-B`, fazendo ping na A e na C.

Você demonstrou com sucesso a conectividade total entre três VPCs usando apenas três anexos e um hub central, uma solução muito mais limpa e escalável do que a malha de 3 conexões de peering que seria necessária.
