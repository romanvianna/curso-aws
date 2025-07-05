# Módulo 1.1: O que é VPC?

**Tempo de Aula:** 45 minutos de teoria, 15 minutos de prática

## 1. Conceitos Fundamentais (Teoria Aprofundada)

### A Rede como um Tecido Conectivo
No coração de toda a computação distribuída está a **rede**. Ela é o tecido conectivo que permite que sistemas distintos se comuniquem. Historicamente, isso era feito com cabos físicos, switches e roteadores em um data center. O desafio fundamental sempre foi o **endereçamento**: como um computador encontra o outro em um mar de dispositivos?

A resposta foi o **Protocolo de Internet (IP)**, que atribui um endereço único a cada dispositivo. Com a explosão da internet, os endereços IPv4 se tornaram um recurso escasso. Para resolver isso, a especificação **RFC 1918** foi criada, reservando faixas de endereços IP para uso em **redes privadas**. Esses endereços (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) não são roteáveis na internet pública, permitindo que milhões de empresas e residências usem os mesmos endereços internamente sem conflito. A comunicação com o mundo exterior é feita através de uma tecnologia chamada **NAT (Network Address Translation)**.

### A Virtualização da Rede: Software-Defined Networking (SDN)
A **Amazon Virtual Private Cloud (VPC)** é a resposta da AWS para o data center tradicional. É uma implementação de **Software-Defined Networking (SDN)**, que pega todos os conceitos de hardware de rede (roteadores, switches, firewalls) e os transforma em serviços virtuais e programáveis. 

Ao criar uma VPC, você está reivindicando um pedaço do espaço de endereçamento IP privado (definido por um bloco **CIDR - Classless Inter-Domain Routing**) que é seu e logicamente isolado de todos os outros clientes da AWS. Você se torna o administrador da sua própria rede virtual, com controle total sobre seu layout, segurança e conectividade.

## 2. Arquitetura e Casos de Uso

### Cenário Simples: O Sandbox do Desenvolvedor
Um desenvolvedor solo ou uma pequena startup precisa de um lugar para testar rapidamente uma nova ideia de aplicação. O objetivo é a velocidade e a conveniência, não a governança complexa.

-   **Implementação:** O desenvolvedor usa a **VPC Padrão (Default VPC)** que a AWS cria em cada região. Esta VPC vem pré-configurada com sub-redes públicas, um Internet Gateway e rotas que permitem o acesso imediato à internet. Ele pode lançar uma instância EC2 em segundos e começar a trabalhar. 
-   **Justificativa:** Neste contexto, a falta de segmentação não é um risco crítico. O valor está em remover as barreiras de infraestrutura para a inovação rápida. A VPC Padrão é uma ferramenta de conveniência para este fim.

### Cenário Corporativo Robusto: A Base de uma Instituição Financeira
Uma grande instituição financeira está migrando suas aplicações de trading para a AWS. Os requisitos são máximos: segurança, conformidade (PCI DSS, BACEN), auditabilidade e resiliência.

-   **Implementação:** O uso da VPC Padrão é estritamente proibido por políticas de governança (usando AWS Organizations SCPs). A equipe de arquitetura de nuvem projeta e implanta uma **VPC Customizada** usando Terraform.
    -   **Planejamento de IP:** O bloco CIDR (`10.50.0.0/16`) é cuidadosamente escolhido para não ter sobreposição com os data centers on-premises, antecipando uma futura conexão híbrida via Direct Connect.
    -   **Segmentação em Camadas:** A VPC é dividida em múltiplas camadas de sub-redes (Web, App, Dados), cada uma com suas próprias Tabelas de Rotas e Network ACLs, garantindo que um banco de dados nunca possa ser exposto à internet.
    -   **Governança:** A VPC e todos os seus sub-recursos são marcados com tags (`Project: TradingApp`, `CostCenter: 12345`, `Compliance: PCI`).
-   **Justificativa:** A VPC Customizada fornece o controle granular necessário para construir um ambiente que atenda a requisitos rigorosos de segurança e conformidade, tratando a rede como uma fundação crítica da arquitetura.

## 3. Melhores Práticas (AWS Well-Architected)

-   **Segurança:** Sempre use VPCs Customizadas para cargas de trabalho de produção. Projete com uma arquitetura de múltiplas camadas (pública/privada) para minimizar a superfície de ataque. Use o princípio do menor privilégio para todas as configurações de rede.
-   **Confiabilidade:** Projete sua VPC para abranger múltiplas Zonas de Disponibilidade (AZs), com sub-redes em cada AZ para cada camada da sua aplicação, permitindo arquiteturas de alta disponibilidade.
-   **Otimização de Custos:** O serviço de VPC em si é gratuito, mas as decisões de arquitetura (como o tráfego entre AZs) têm implicações de custo. Planeje sua topologia com cuidado.
-   **Excelência Operacional:** Use Infraestrutura como Código (IaC) como Terraform ou CloudFormation para definir e gerenciar sua VPC. Isso garante repetibilidade, controle de versão e automação.
-   **Otimização de Performance:** A escolha do layout da VPC pode impactar a latência. Para aplicações que exigem latência ultrabaixa, considere o uso de Placement Groups dentro da sua VPC.

## 4. Guia Prático (Laboratório)

O laboratório prático se concentra em explorar o console da VPC para identificar os componentes de uma VPC (seja a Padrão ou uma Customizada) e mapeá-los para os conceitos teóricos discutidos. O objetivo é construir uma familiaridade com a interface e os termos da AWS, como VPC ID, Bloco CIDR, Tabela de Rotas Principal e NACL Padrão.
