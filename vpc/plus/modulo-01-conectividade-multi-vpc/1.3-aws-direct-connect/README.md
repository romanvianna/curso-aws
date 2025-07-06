# Módulo 1.3: AWS Direct Connect

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento básico de redes (roteamento, BGP, VLANs).
*   Compreensão dos conceitos de VPC e conectividade com a internet.
*   Noções sobre VPNs Site-to-Site.

## Objetivos

*   Entender os desafios e a necessidade da conectividade híbrida (nuvem para on-premises) em ambientes corporativos.
*   Comparar a conectividade via VPN baseada na internet com a conectividade dedicada do Direct Connect, destacando as vantagens de cada um.
*   Analisar a arquitetura, os modelos de conexão e os componentes do Direct Connect (Conexões, VIFs - Virtual Interfaces, Gateways).
*   Compreender o papel do Direct Connect Gateway (DXGW) e sua integração com o Transit Gateway (TGW).
*   Realizar uma simulação de configuração do Direct Connect para conectar uma VPC a uma rede on-premises, focando nos componentes do lado da AWS.

---

## 1. Conectividade Híbrida: On-Premises para a Nuvem (Teoria - 60 min)

Para a maioria das grandes empresas, a adoção da nuvem não é um evento de "virar a chave" onde tudo é migrado de uma vez. É uma jornada, resultando em uma **arquitetura híbrida**, onde alguns recursos permanecem no data center local (on-premises) e outros rodam na nuvem da AWS. Nesses cenários, uma conectividade de rede confiável, segura e de alta performance entre o on-premises e a nuvem é fundamental.

Existem duas maneiras principais de estabelecer essa conectividade híbrida:

1.  **AWS Site-to-Site VPN:** Cria um túnel criptografado entre sua rede on-premises e sua VPC **através da internet pública**. É uma solução rápida de configurar e de custo relativamente baixo, mas sua performance e confiabilidade estão sujeitas à variabilidade da internet. Ideal para casos de uso menos críticos, backup ou como contingência para o Direct Connect.

2.  **AWS Direct Connect (DX):** Cria uma **conexão de rede privada e dedicada** entre seu data center e a infraestrutura da AWS. O tráfego nunca passa pela internet pública.

### O que é o AWS Direct Connect?

O Direct Connect é um serviço que estabelece uma conexão de fibra óptica física e privada entre sua infraestrutura (data center, escritório, colocation) e um **Local do Direct Connect**. Um Local do DX é um data center onde a AWS tem um ponto de presença de rede. A partir daí, sua conexão tem um caminho privado e de alta largura de banda para a região da AWS de sua escolha.

### Por que usar o Direct Connect?

*   **Performance Consistente:** Como o tráfego não compete com o tráfego da internet pública, a latência é menor e muito mais previsível. A perda de pacotes é reduzida drasticamente, o que é crucial para aplicações sensíveis à latência (ex: bancos de dados, aplicações financeiras).
*   **Alta Largura de Banda:** O Direct Connect oferece portas dedicadas de 1 Gbps, 10 Gbps, e até 100 Gbps, muito mais do que o que é tipicamente viável sobre uma VPN na internet, suportando grandes volumes de dados (ex: migrações de dados, replicação de bancos de dados).
*   **Segurança Aprimorada:** O tráfego flui por uma conexão privada, o que pode ser um requisito para indústrias com dados altamente sensíveis ou regulamentados (ex: saúde, finanças) que não podem transitar pela internet pública.
*   **Redução de Custos de Transferência de Dados:** Para grandes volumes de tráfego, o custo de transferência de dados (Data Transfer Out) através do Direct Connect é significativamente menor do que pela internet, tornando-o mais econômico a longo prazo.

### Componentes e Arquitetura do Direct Connect

1.  **Conexão (Connection):** A conexão física de fibra óptica. Existem dois modelos:
    *   **Dedicada:** Uma porta de 1/10/100 Gbps dedicada a um único cliente. Você solicita diretamente à AWS e trabalha com um parceiro para estabelecer o "último quilômetro" de fibra do seu data center até o Local do DX.
    *   **Hospedada (Hosted):** Um parceiro da Rede de Parceiros da AWS (APN) provisiona uma conexão de alta capacidade e a "fatia" em conexões menores (ex: 50 Mbps, 100 Mbps, 500 Mbps, 1 Gbps) que eles revendem para múltiplos clientes. É uma opção mais flexível e de menor custo para começar, ideal para empresas menores ou para testar o serviço.

2.  **Interfaces Virtuais (VIFs - Virtual Interfaces):** Uma conexão física do Direct Connect pode ser logicamente dividida para acessar diferentes ambientes da AWS usando VIFs. Cada VIF é uma conexão BGP separada.
    *   **VIF Privada (Private VIF):** Usada para se conectar a uma **VPC** através de um **Virtual Private Gateway (VGW)** ou um **Direct Connect Gateway (DXGW)**. O tráfego usa endereços IP privados.
    *   **VIF Pública (Public VIF):** Usada para se conectar aos **endpoints públicos** de serviços da AWS (como S3, DynamoDB, SQS) sem passar pela internet. O tráfego usa endereços IP públicos.
    *   **VIF de Trânsito (Transit VIF):** Usada para se conectar a um **Transit Gateway**. Esta é a abordagem moderna e escalável, permitindo que uma única conexão DX forneça conectividade on-premises para centenas de VPCs anexadas ao mesmo TGW.

3.  **Gateways:**
    *   **Virtual Private Gateway (VGW):** O gateway do lado da VPC para conexões VPN e Direct Connect (modelo mais antigo). Anexado a uma única VPC. Permite a propagação de rotas para a tabela de rotas da VPC.
    *   **Direct Connect Gateway (DXGW):** Um gateway global que permite que uma única conexão DX se conecte a VPCs em **qualquer região** (exceto China) e em **múltiplas contas AWS**. Ele é um recurso intermediário entre a VIF e o VGW/TGW.
    *   **Transit Gateway (TGW):** Como vimos no Módulo 1.2, o hub de rede regional. Anexar uma VIF de Trânsito a um TGW é a forma recomendada de escalar a conectividade híbrida, permitindo que o tráfego on-premises acesse qualquer VPC conectada ao TGW.

## 2. Simulação de Configuração do Direct Connect (Prática - 60 min)

Provisionar uma conexão física do Direct Connect é um processo que leva semanas e envolve contratos e trabalho com parceiros de rede. Portanto, não podemos implementá-lo em um laboratório. No entanto, podemos **simular a configuração lógica** dos componentes do lado da AWS, o que é um exercício valioso para entender o fluxo.

### Cenário: Conectando um Data Center On-Premises à AWS

Uma empresa está migrando parte de sua infraestrutura para a AWS e precisa estabelecer uma conexão privada e de alta largura de banda entre seu data center on-premises e sua VPC na AWS para replicação de dados e acesso a aplicações. Eles decidiram usar o Direct Connect.

### Roteiro Prático (Simulação no Console da AWS)

**Passo 1: Criar o Virtual Private Gateway (VGW)**
*   Este é o componente do lado da VPC que receberá a conexão do Direct Connect (ou VPN).
1.  Navegue até **VPC > Virtual Private Gateways > Create virtual private gateway**.
2.  **Name tag:** `Lab-VGW`
3.  Deixe o ASN como padrão (`Amazon default ASN`) e clique em **"Create"**.
4.  Com o `Lab-VGW` selecionado, vá em **Actions > Attach to VPC** e selecione sua `Lab-VPC` (criada no Módulo 3.1).

**Passo 2: Criar o Direct Connect Gateway (DXGW)**
*   Este é um componente global que permite conectar sua conexão DX a VPCs em diferentes regiões ou contas.
1.  Navegue até o console do **Direct Connect > Direct Connect gateways > Create Direct Connect gateway**.
2.  **Name:** `Lab-DXGW`
3.  **Amazon-side ASN:** Insira um número de ASN privado (ex: `65001`). Este ASN será usado para a sessão BGP entre o DXGW e seu roteador on-premises.
4.  Clique em **"Create"**.

**Passo 3: Associar o VGW ao DXGW**
*   Esta associação permite que o tráfego do DXGW seja roteado para a VPC através do VGW.
1.  Selecione o `Lab-DXGW` que você criou.
2.  Vá para a aba **"Gateway associations" > "Associate gateway"**.
3.  Selecione o `Lab-VGW` na lista e clique em **"Associate gateway"**.

**Passo 4: Simular a Criação da Conexão e da VIF (Discussão da Interface)**
*   Estes são os passos que não podemos concluir em um laboratório, mas é importante entender a interface e o processo.
1.  Vá para **Direct Connect > Connections > Create connection**.
    *   Observe as opções: você precisa escolher um Local do DX (onde sua infraestrutura se conectará fisicamente), a largura de banda, e o parceiro (se aplicável). Após a solicitação, a AWS e o parceito trabalharão para estabelecer a conexão física.
2.  Assumindo que tivéssemos uma conexão ativa, iríamos para a aba **"Virtual interfaces" > "Create virtual interface"**.
3.  **Tipo de VIF:** Selecionaríamos `Private` (para conectar a uma VPC).
4.  **Connection:** Escolheríamos nossa conexão física ativa.
5.  **Gateway type:** Selecionaríamos `Direct Connect gateway` e escolheríamos nosso `Lab-DXGW`.
6.  **VLAN ID:** Um ID para isolar o tráfego na conexão física (fornecido pelo seu provedor de rede).
7.  **BGP ASN:** O ASN do seu roteador on-premises.
8.  **Peer IP Addresses:** Você forneceria os endereços IP para a sessão de roteamento BGP entre o seu roteador on-premises e o da AWS.

**Passo 5: Configurar o Roteamento na VPC (Propagação de Rotas)**
*   O passo final, e o mais importante, seria configurar a tabela de rotas da sua VPC para aprender as rotas da sua rede on-premises.
1.  Vá para a **tabela de rotas** da sua sub-rede privada na `Lab-VPC` (ex: `Lab-Private-RT`).
2.  Vá para a aba **"Route Propagation"**.
3.  Clique em **"Edit route propagation"** e habilite a propagação de rota para o seu `Lab-VGW`.
4.  Isso instruiria a tabela de rotas a aprender automaticamente as rotas da sua rede on-premises (anunciadas via BGP sobre a VIF) e a instalá-las, apontando para o VGW como o `target`.
5.  Isso permitiria que as instâncias na VPC se comunicassem com os servidores na rede on-premises usando IPs privados.

Este exercício, embora simulado, demonstra o fluxo lógico e os componentes envolvidos na configuração de uma conexão privada e dedicada entre um data center on-premises e a AWS, uma capacidade essencial para arquiteturas híbridas de nível empresarial.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Planejamento é Crucial:** O Direct Connect exige um planejamento detalhado de endereçamento IP, roteamento (BGP) e largura de banda. Certifique-se de que seus blocos CIDR on-premises não se sobreponham aos da AWS.
*   **Redundância:** Para ambientes de produção, sempre configure múltiplas conexões Direct Connect para diferentes locais do DX e/ou diferentes provedores de rede para garantir alta disponibilidade e resiliência.
*   **Transit Gateway para Escalabilidade:** Para conectar sua rede on-premises a múltiplas VPCs na AWS, a abordagem recomendada é usar uma VIF de Trânsito com um Transit Gateway. Isso simplifica o roteamento e a gestão de conexões.
*   **VPN como Backup:** Considere configurar uma VPN Site-to-Site como um backup para sua conexão Direct Connect. Em caso de falha do DX, o tráfego pode ser roteado automaticamente pela VPN sobre a internet.
*   **Monitoramento:** Monitore a utilização da largura de banda e a latência da sua conexão Direct Connect usando CloudWatch. Configure alarmes para ser notificado sobre problemas de conectividade.
*   **Segurança:** Embora o Direct Connect forneça uma conexão privada, ele não é um firewall. Use Security Groups e Network ACLs em suas VPCs para controlar o tráfego que entra e sai da sua rede on-premises.
*   **Custo:** O Direct Connect tem custos de porta (por hora) e de transferência de dados de saída. Avalie o volume de tráfego para justificar o investimento em comparação com uma VPN.