# Módulo 1.1: O que é VPC?

**Tempo de Aula:** 45 minutos de teoria, 15 minutos de prática

## Pré-requisitos

*   Conhecimentos básicos de redes (TCP/IP, endereçamento IP, roteamento).
*   Noções sobre virtualização e computação em nuvem.
*   Acesso a uma conta AWS (mesmo que seja a camada gratuita).

## Objetivos

*   Compreender o conceito de Virtual Private Cloud (VPC) como um data center virtual isolado na AWS.
*   Entender a VPC como uma implementação de Software-Defined Networking (SDN).
*   Diferenciar entre a VPC Padrão (Default VPC) e VPCs Customizadas, e seus casos de uso.
*   Explorar os componentes fundamentais de uma VPC (CIDR, sub-redes, tabelas de rotas, Internet Gateway, Network ACLs, Security Groups).
*   Analisar as implicações de segurança e arquitetura ao projetar uma VPC.

---

## 1. Conceitos Fundamentais: A Rede como um Tecido Conectivo (Teoria - 45 min)

No coração de toda a computação distribuída está a **rede**. Ela é o tecido conectivo que permite que sistemas distintos se comuniquem. Historicamente, isso era feito com cabos físicos, switches e roteadores em um data center. O desafio fundamental sempre foi o **endereçamento**: como um computador encontra o outro em um mar de dispositivos?

A resposta foi o **Protocolo de Internet (IP)**, que atribui um endereço lógico único a cada dispositivo. Com a explosão da internet, os endereços IPv4 públicos se tornaram um recurso escasso. Para resolver isso, a especificação **RFC 1918** foi criada, reservando faixas de endereços IP para uso em **redes privadas**. Esses endereços (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) não são roteáveis na internet pública, permitindo que milhões de empresas e residências usem os mesmos endereços internamente sem conflito. A comunicação com o mundo exterior é feita através de uma tecnologia chamada **NAT (Network Address Translation)**.

### A Virtualização da Rede: Software-Defined Networking (SDN)

A **Amazon Virtual Private Cloud (VPC)** é a resposta da AWS para o data center tradicional. É uma implementação de **Software-Defined Networking (SDN)**, que pega todos os conceitos de hardware de rede (roteadores, switches, firewalls) e os transforma em serviços virtuais e programáveis. Em essência, a AWS abstrai a complexidade da infraestrutura física subjacente e permite que você defina sua rede usando software.

Ao criar uma VPC, você está reivindicando um pedaço do espaço de endereçamento IP privado (definido por um bloco **CIDR - Classless Inter-Domain Routing**) que é seu e logicamente isolado de todos os outros clientes da AWS. Você se torna o administrador da sua própria rede virtual, com controle total sobre seu layout, segurança e conectividade. É como ter seu próprio data center virtual, mas com a escalabilidade e flexibilidade da nuvem.

## 2. Arquitetura e Casos de Uso: VPC Padrão vs. VPC Customizada

### VPC Padrão (Default VPC)

*   **Conceito:** A AWS cria automaticamente uma VPC em cada região da sua conta. Ela vem pré-configurada com uma sub-rede pública em cada Zona de Disponibilidade, um Internet Gateway e tabelas de rotas que permitem o acesso imediato à internet.
*   **Caso de Uso:** Ideal para desenvolvedores que estão começando, para testes rápidos, ou para cargas de trabalho que não exigem isolamento de rede complexo ou personalização. É uma ferramenta de conveniência para prototipagem e aprendizado.
*   **Exemplo Real:** Um desenvolvedor solo ou uma pequena startup precisa de um lugar para testar rapidamente uma nova ideia de aplicação web. O objetivo é a velocidade e a conveniência, não a governança complexa. A VPC Padrão permite lançar uma instância EC2 em segundos e começar a trabalhar sem se preocupar com a configuração de rede inicial.

### VPC Customizada

*   **Conceito:** Uma VPC que você cria e configura do zero, definindo seu próprio bloco CIDR, sub-redes, tabelas de rotas, gateways e regras de segurança. Oferece controle total sobre o ambiente de rede.
*   **Caso de Uso:** Essencial para cargas de trabalho de produção, ambientes corporativos, aplicações que exigem alta segurança, conformidade, conectividade híbrida (com data centers on-premises) ou topologias de rede complexas.
*   **Exemplo Real:** Uma grande instituição financeira está migrando suas aplicações de trading para a AWS. Os requisitos são máximos: segurança, conformidade (PCI DSS, BACEN), auditabilidade e resiliência. O uso da VPC Padrão é estritamente proibido por políticas de governança. A equipe de arquitetura de nuvem projeta e implanta uma **VPC Customizada** usando Infraestrutura como Código (IaC) como Terraform. O bloco CIDR (`10.50.0.0/16`) é cuidadosamente escolhido para não ter sobreposição com os data centers on-premises, antecipando uma futura conexão híbrida via Direct Connect. A VPC é dividida em múltiplas camadas de sub-redes (Web, App, Dados), cada uma com suas próprias Tabelas de Rotas e Network ACLs, garantindo que um banco de dados nunca possa ser exposto à internet. Todos os recursos são marcados com tags (`Project: TradingApp`, `CostCenter: 12345`, `Compliance: PCI`) para governança e rastreamento de custos.

## 3. Componentes Fundamentais de uma VPC

Uma VPC é composta por diversos elementos que trabalham juntos para formar sua rede virtual:

*   **Bloco CIDR (Classless Inter-Domain Routing):** Define o intervalo de endereços IP privados da sua VPC (ex: `10.0.0.0/16`). É o espaço de endereçamento lógico da sua rede.
*   **Sub-redes:** Divisões da sua VPC em segmentos menores. Podem ser públicas (com rota para Internet Gateway) ou privadas (sem rota direta para Internet Gateway). Cada sub-rede reside em uma única Zona de Disponibilidade (AZ).
*   **Tabelas de Rotas:** Conjuntos de regras que controlam o tráfego de saída das sub-redes. Cada sub-rede deve estar associada a uma tabela de rotas.
*   **Internet Gateway (IGW):** Um componente da VPC que permite a comunicação entre instâncias na sua VPC e a internet. É um gateway escalável e redundante.
*   **Network ACLs (NACLs):** Firewalls stateless em nível de sub-rede que controlam o tráfego de entrada e saída de uma ou mais sub-redes. Permitem regras de `ALLOW` e `DENY`.
*   **Security Groups (SGs):** Firewalls stateful em nível de instância que controlam o tráfego de entrada e saída de uma ou mais instâncias EC2. Permitem apenas regras de `ALLOW`.

## 4. Guia Prático (Laboratório - 15 min)

O laboratório prático se concentra em explorar o console da VPC para identificar os componentes de uma VPC (seja a Padrão ou uma Customizada) e mapeá-los para os conceitos teóricos discutidos. O objetivo é construir uma familiaridade com a interface e os termos da AWS, como VPC ID, Bloco CIDR, Tabela de Rotas Principal e NACL Padrão.

**Roteiro:**
1.  Navegue até o console da AWS e selecione o serviço **VPC**.
2.  No painel de navegação esquerdo, clique em **"Your VPCs"**. Observe a VPC Padrão (se houver) e qualquer VPC customizada que você possa ter.
3.  Clique no ID de uma VPC e explore suas abas: **"Subnets"**, **"Route Tables"**, **"Internet Gateways"**, **"Network ACLs"**, **"Security Groups"**.
4.  Para cada componente, tente identificar:
    *   Seu ID e nome.
    *   O bloco CIDR associado (para VPCs e sub-redes).
    *   Suas associações (ex: qual sub-rede está associada a qual tabela de rotas).
    *   Suas regras (para NACLs e Security Groups).
5.  **Discussão:** Como esses componentes se relacionam para permitir ou bloquear o tráfego? Qual a diferença entre as regras de uma NACL e um Security Group?

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Sempre use VPCs Customizadas para Produção:** A Default VPC é conveniente, mas não oferece o nível de controle e isolamento necessário para ambientes de produção ou que exigem conformidade.
*   **Planejamento de IP:** Planeje cuidadosamente seus blocos CIDR de VPC e sub-redes para evitar sobreposição com redes on-premises (se houver planos de conectividade híbrida) e para permitir crescimento futuro.
*   **Múltiplas Zonas de Disponibilidade (AZs):** Projete sua VPC para abranger múltiplas AZs, criando sub-redes em cada AZ para cada camada da sua aplicação. Isso é fundamental para alta disponibilidade e resiliência a falhas de AZ.
*   **Princípio do Menor Privilégio:** Aplique o princípio do menor privilégio em todas as configurações de rede. Permita apenas o tráfego estritamente necessário.
*   **Infraestrutura como Código (IaC):** Use ferramentas como Terraform ou AWS CloudFormation para definir e gerenciar sua VPC. Isso garante repetibilidade, controle de versão, automação e reduz erros manuais.
*   **Segmentação de Rede:** Divida sua VPC em sub-redes lógicas (ex: pública, privada, banco de dados) e use Security Groups e NACLs para controlar o fluxo de tráfego entre elas.
*   **Tags:** Utilize tags de forma consistente em todos os seus recursos de VPC para facilitar a organização, o rastreamento de custos e a automação.
*   **Monitoramento:** Habilite VPC Flow Logs e CloudTrail para monitorar o tráfego de rede e as atividades da API na sua VPC, o que é crucial para segurança e troubleshooting.