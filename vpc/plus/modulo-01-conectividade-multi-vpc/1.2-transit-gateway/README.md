# Módulo 1.2: Transit Gateway

**Tempo de Aula:** 90 minutos de teoria, 90 minutos de prática

## Pré-requisitos

*   Conhecimento sólido dos conceitos de VPC, sub-redes e tabelas de rotas.
*   Compreensão das limitações do VPC Peering, especialmente a não-transitividade (Módulo 1.1).
*   Familiaridade com o console da AWS e a criação de instâncias EC2.
*   Planejamento de endereçamento IP para VPCs não sobrepostas.

## Objetivos

*   Entender o conceito de uma topologia de rede Hub-and-Spoke e suas vantagens em ambientes de nuvem complexos.
*   Posicionar o AWS Transit Gateway (TGW) como um roteador de nuvem centralizado que permite uma arquitetura Hub-and-Spoke escalável.
*   Analisar os componentes do Transit Gateway: o TGW em si, anexos (attachments), tabelas de rotas do TGW, associações e propagações.
*   Implementar um Transit Gateway para conectar múltiplas VPCs de forma escalável, superando as limitações do VPC Peering.
*   Discutir cenários de uso avançados do TGW, incluindo conectividade híbrida e segmentação de rede.

---

## 1. Topologia de Rede Hub-and-Spoke (Teoria - 90 min)

### O Problema da Malha de Peering

Como vimos no Módulo 1.1, o VPC Peering não é transitivo. Isso significa que para conectar múltiplas VPCs de forma que todas possam se comunicar entre si, precisamos criar uma **malha completa (full mesh)** de conexões de peering. 

*   Para 3 VPCs, são 3 conexões.
*   Para 4 VPCs, são 6 conexões.
*   Para 10 VPCs, são 45 conexões.

Essa abordagem não escala. Gerenciar dezenas ou centenas de conexões de peering e suas respectivas entradas em tabelas de rotas é um pesadelo operacional, propenso a erros e extremamente complexo. Além disso, a depuração de problemas de conectividade em uma malha de peering é muito difícil.

### A Solução: O Modelo Hub-and-Spoke

A solução para este problema de escala é uma topologia de rede clássica chamada **Hub-and-Spoke**. 

*   **Conceito:** Em vez de conectar cada local diretamente a todos os outros, você estabelece um **hub central**. Todos os locais periféricos (os **spokes**) se conectam apenas ao hub central. A comunicação entre dois spokes passa **através** do hub.
*   **Vantagens:**
    *   **Simplicidade:** Cada spoke só precisa gerenciar uma única conexão (para o hub).
    *   **Escalabilidade:** Adicionar um novo spoke (uma nova VPC, um novo data center on-premises) é fácil. Você simplesmente o conecta ao hub, e ele ganha automaticamente a capacidade de se comunicar com todos os outros spokes já conectados.
    *   **Controle Centralizado:** O hub se torna um ponto central para monitoramento, segurança e aplicação de políticas de roteamento. Isso facilita a auditoria e a governança.

### AWS Transit Gateway: O Hub da sua Nuvem

O **AWS Transit Gateway (TGW)** é um serviço gerenciado que atua como um **roteador de nuvem regional e centralizado**, permitindo que você implemente uma arquitetura Hub-and-Spoke na AWS. Ele simplifica a conectividade de rede em ambientes multi-VPC e híbridos.

*   **Como Funciona:** O TGW atua como um hub altamente escalável e resiliente. Você anexa suas VPCs (e também suas conexões on-premises, como VPNs e Direct Connect) ao TGW. O TGW então facilita o roteamento entre todos os anexos, agindo como um roteador de tráfego.

### Componentes do Transit Gateway

1.  **O Transit Gateway em si:** O recurso central que atua como o roteador. É um serviço regional, o que significa que ele opera dentro de uma região da AWS.

2.  **Anexos (Attachments):** Uma conexão de uma rede (como uma VPC, uma VPN, ou um Direct Connect Gateway) ao TGW. Quando você anexa uma VPC, você deve especificar em quais sub-redes o TGW deve criar uma **interface de rede (ENI)**. O TGW usa essas ENIs para rotear o tráfego de e para a VPC. Cada anexo tem um ID único (`tgw-attach-xxxxxxxx`).

3.  **Tabelas de Rotas do TGW:** Esta é a parte mais poderosa e flexível do TGW. O TGW tem sua **própria** tabela de rotas, separada das tabelas de rotas das VPCs. 
    *   Esta tabela determina como o tráfego é roteado **dentro** do TGW, entre os diferentes anexos.
    *   Por padrão, o TGW vem com uma tabela de rotas padrão que tem uma rota **propagada** de cada anexo. Isso significa que, por padrão, qualquer anexo pode rotear para qualquer outro anexo (comunicação total).
    *   Você pode criar múltiplas tabelas de rotas no TGW para criar domínios de roteamento isolados. Por exemplo, uma tabela de rotas para VPCs de produção e outra para VPCs de desenvolvimento, impedindo a comunicação direta entre elas.

4.  **Propagações (Route Propagations):** Uma propagação é uma regra que diz ao TGW para aprender automaticamente as rotas de um anexo (ex: o CIDR de uma VPC anexada) e adicioná-las a uma tabela de rotas do TGW. Isso simplifica o gerenciamento de rotas, pois você não precisa adicionar manualmente as rotas de cada VPC ao TGW.

5.  **Associações (Associations):** Uma associação vincula um anexo a uma tabela de rotas do TGW. É isso que determina qual "mapa" (tabela de rotas do TGW) um anexo usará para tomar suas decisões de roteamento. Um anexo só pode ser associado a uma tabela de rotas do TGW por vez.

### Fluxo de Tráfego com TGW

1.  Uma instância na VPC-A (Spoke A) envia um pacote para uma instância na VPC-B (Spoke B).
2.  A **tabela de rotas da sub-rede na VPC-A** tem uma rota para o CIDR da VPC-B, com o `target` sendo o **Transit Gateway** (`tgw-xxxxxxxx`).
3.  O tráfego é enviado para a ENI do TGW na VPC-A.
4.  O TGW recebe o pacote e consulta sua **tabela de rotas interna** (a tabela de rotas do TGW associada ao anexo da VPC-A). Ele encontra uma rota para o CIDR da VPC-B, que aponta para o **anexo da VPC-B**.
5.  O TGW encaminha o pacote através da ENI do TGW na VPC-B.
6.  O pacote chega à instância de destino na VPC-B.

O TGW resolve o problema da transitividade e da malha de peering, fornecendo uma solução de conectividade de rede centralizada, escalável e gerenciável para ambientes de nuvem complexos.

## 2. Implementação de Transit Gateway (Prática - 90 min)

Neste laboratório, vamos conectar três VPCs usando um Transit Gateway, demonstrando como ele simplifica a conectividade em escala e permite a comunicação entre elas.

### Cenário: Conectando Ambientes de Desenvolvimento, Teste e Produção

Uma empresa possui ambientes de desenvolvimento, teste e produção em VPCs separadas para isolamento. Eles precisam de conectividade entre esses ambientes para fluxos de trabalho como implantação de código, acesso a serviços compartilhados ou replicação de dados. Em vez de usar VPC Peering em malha, eles implementarão um Transit Gateway como o hub central.

*   **VPC-Dev:** `10.10.0.0/16`
*   **VPC-Test:** `10.20.0.0/16`
*   **VPC-Prod:** `10.30.0.0/16`
*   **Objetivo:** Permitir que instâncias em cada VPC se comuniquem com as instâncias nas outras duas VPCs, passando pelo TGW.

### Roteiro Prático

**Passo 1: Criar as VPCs e Instâncias**
1.  Crie três VPCs com os CIDRs acima (ex: `VPC-Dev`, `VPC-Test`, `VPC-Prod`). Em cada uma, crie uma sub-rede pública (ex: `10.10.1.0/24`, `10.20.1.0/24`, `10.30.1.0/24`) e lance uma instância EC2 (`t2.micro`, Amazon Linux 2) com um IP público para acesso SSH inicial. Certifique-se de que os Security Groups permitam SSH do seu IP local.

**Passo 2: Criar o Transit Gateway**
1.  Navegue até **VPC > Transit Gateways > Create transit gateway**.
2.  **Name tag:** `Lab-TGW`
3.  Deixe as outras opções como padrão (ex: a criação da tabela de rotas padrão e a propagação automática estarão habilitadas). Clique em **"Create transit gateway"**. (Pode levar alguns minutos para provisionar).

**Passo 3: Anexar as VPCs ao TGW**
1.  Vá para **Transit gateway attachments > Create transit gateway attachment**.
2.  **Anexo para VPC-Dev:**
    *   **Transit gateway ID:** Selecione seu `Lab-TGW`.
    *   **Attachment type:** `VPC`.
    *   **VPC ID:** Selecione `VPC-Dev`.
    *   **Subnet IDs:** Selecione a sub-rede pública dentro da `VPC-Dev` onde a ENI do TGW será criada. (É uma boa prática criar uma sub-rede dedicada para o TGW em cada AZ, mas para este lab, a sub-rede pública existente serve).
    *   Clique em **"Create attachment"**.
3.  **Repita o processo** para criar anexos para a `VPC-Test` e a `VPC-Prod`. Aguarde o status de cada anexo mudar para `available`.

**Passo 4: Verificar a Tabela de Rotas do TGW**
1.  Vá para **Transit gateway route tables**. Selecione a tabela de rotas padrão do seu `Lab-TGW` (geralmente chamada `default`).
2.  Vá para a aba **"Routes"**. Você deve ver três rotas que foram **propagadas** automaticamente a partir dos seus três anexos (os CIDRs das VPCs). O TGW agora sabe como chegar a cada uma das VPCs.

**Passo 5: Atualizar as Tabelas de Rotas das VPCs**
*Este é o passo final e crucial. Cada VPC precisa saber como enviar tráfego para as outras VPCs através do TGW.*
1.  **Para cada VPC (VPC-Dev, VPC-Test, VPC-Prod):**
    *   Vá para a tabela de rotas associada à sub-rede pública daquela VPC.
    *   Edite suas rotas e adicione uma rota padrão (`0.0.0.0/0`) ou rotas específicas para os CIDRs das outras VPCs, apontando para o Transit Gateway.
    *   **Exemplo para VPC-Dev (se usar rotas específicas):**
        *   Vá para a tabela de rotas da sub-rede pública na `VPC-Dev`.
        *   Adicione **duas** rotas:
            *   `Destination: 10.20.0.0/16` (CIDR da `VPC-Test`) -> `Target: Transit Gateway` (selecione seu `Lab-TGW`)
            *   `Destination: 10.30.0.0/16` (CIDR da `VPC-Prod`) -> `Target: Transit Gateway` (selecione seu `Lab-TGW`)
    *   **Alternativa (mais simples para este lab):** Você pode adicionar uma única rota padrão (`0.0.0.0/0`) que aponta para o TGW. **Cuidado:** Isso fará com que todo o tráfego de saída da sub-rede (incluindo para a internet) passe pelo TGW. Se você quiser acesso à internet via IGW, precisará de uma rota mais específica para o TGW e uma rota padrão para o IGW.

**Passo 6: Atualizar os Security Groups**
1.  Para cada uma das três instâncias, modifique seu Security Group para permitir tráfego (ex: ICMP para ping, SSH para acesso administrativo) dos blocos CIDR das outras duas VPCs.
    *   **Exemplo para `Instance-Dev`:** Adicione regras de entrada para `10.20.0.0/16` e `10.30.0.0/16` para as portas necessárias.

**Passo 7: Validar a Conectividade**
1.  Conecte-se via SSH à `Instance-Dev`.
2.  A partir dela, faça ping nos **IPs privados** da `Instance-Test` e da `Instance-Prod`.
3.  Ambos os pings devem funcionar.
4.  Repita o teste a partir da `Instance-Test`, fazendo ping na `Instance-Dev` e na `Instance-Prod`.

Você demonstrou com sucesso a conectividade total entre três VPCs usando apenas três anexos e um hub central (Transit Gateway), uma solução muito mais limpa e escalável do que a malha de 3 conexões de peering que seria necessária.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Hub-and-Spoke é o Padrão:** Para ambientes com mais de 3-4 VPCs que precisam de conectividade mútua, o Transit Gateway é a solução preferida devido à sua escalabilidade e simplicidade de gerenciamento em comparação com o VPC Peering em malha.
*   **Planejamento de CIDR:** Assim como no VPC Peering, os CIDRs das VPCs anexadas ao TGW **não podem se sobrepor**. Um planejamento de endereçamento IP robusto é crucial.
*   **Tabelas de Rotas do TGW:** Utilize as tabelas de rotas do TGW para implementar segmentação de rede e políticas de roteamento complexas. Por exemplo, você pode ter uma tabela de rotas que permite que as VPCs de desenvolvimento se comuniquem entre si, mas não com as VPCs de produção.
*   **Propagação de Rotas:** A propagação de rotas automática simplifica o gerenciamento, mas em cenários complexos, você pode desabilitá-la e gerenciar as rotas manualmente para maior controle.
*   **Conectividade Híbrida:** O TGW é a peça central para conectar sua infraestrutura on-premises (via VPN ou Direct Connect) a múltiplas VPCs na AWS, consolidando o roteamento.
*   **Custo:** O Transit Gateway tem um custo por hora e por GB de dados processados. Monitore essas métricas no CloudWatch para otimização de custos.
*   **IaC para TGW:** Gerencie seu Transit Gateway e seus anexos usando Infraestrutura como Código (Terraform, CloudFormation) para garantir consistência, automação e controle de versão.
*   **Monitoramento:** Utilize CloudWatch para monitorar o TGW (métricas de bytes, pacotes) e VPC Flow Logs para o tráfego que passa por ele, auxiliando no troubleshooting e auditoria.