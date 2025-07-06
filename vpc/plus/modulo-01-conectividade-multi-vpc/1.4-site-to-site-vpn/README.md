# Módulo 1.4: Site-to-Site VPN

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento básico de redes (roteamento, IPsec, criptografia).
*   Familiaridade com os conceitos de VPC e Virtual Private Gateway (VGW) ou Transit Gateway (TGW).
*   Noções sobre o funcionamento da internet pública.

## Objetivos

*   Entender os conceitos fundamentais de uma VPN IPsec, incluindo túneis, criptografia e troca de chaves (IKE).
*   Analisar a arquitetura de uma conexão AWS Site-to-Site VPN, incluindo seus componentes (Customer Gateway, VGW/TGW, VPN Connection).
*   Compreender a importância e o design de uma conexão VPN redundante e de alta disponibilidade.
*   Implementar uma conexão Site-to-Site VPN entre uma VPC e uma rede on-premises simulada, focando na configuração do lado da AWS.
*   Discutir os casos de uso e as melhores práticas para VPNs em cenários de nuvem híbrida.

---

## 1. VPNs IPsec e Conectividade Híbrida (Teoria - 60 min)

Quando uma conexão dedicada como o Direct Connect não é viável (devido a custo, tempo ou localização), a maneira mais comum de estabelecer uma conectividade híbrida é através de uma **VPN (Virtual Private Network)**. Uma VPN cria um "túnel" seguro e criptografado através de uma rede não confiável (a internet pública), estendendo uma rede privada para além de seus limites físicos.

O padrão da indústria para conectar redes (site-to-site) é o **IPsec (Internet Protocol Security)**.

### Como uma VPN IPsec Funciona?

Uma VPN IPsec estabelece um túnel entre dois **gateways** (um na sua rede on-premises, chamado de **Customer Gateway**, e um na AWS, chamado de **Virtual Private Gateway** ou **Transit Gateway**). Todo o tráfego que passa entre as duas redes é criptografado, garantindo confidencialidade e integridade.

O processo de estabelecimento de um túnel IPsec envolve duas fases principais:

1.  **Fase 1: IKE (Internet Key Exchange)**
    *   **Propósito:** Os dois gateways se autenticam mutuamente e estabelecem um canal seguro para se comunicarem. Eles negociam os algoritmos de criptografia e hashing e geram chaves de sessão compartilhadas. Isso cria a **associação de segurança (Security Association - SA)** da Fase 1, também conhecida como IKE SA ou ISAKMP SA.

2.  **Fase 2: O Túnel IPsec (IPsec SA)**
    *   **Propósito:** Usando o canal seguro da Fase 1, os gateways estabelecem o túnel IPsec real através do qual os dados do usuário fluirão. Eles negociam os parâmetros para este túnel (a SA da Fase 2, também conhecida como IPsec SA ou Child SA).
    *   **Encapsulamento:** Quando uma instância na sua VPC envia um pacote para um servidor on-premises, o gateway da AWS pega o pacote IP original, o **criptografa** e o **encapsula** dentro de um novo pacote IP. O endereço de destino deste novo pacote é o endereço IP público do seu Customer Gateway. O pacote viaja pela internet e, ao chegar, seu gateway o desencapsula, o descriptografa e o entrega ao servidor de destino final.

### Arquitetura da AWS Site-to-Site VPN

*   **Customer Gateway (CGW):** Um recurso na AWS que representa o seu dispositivo de VPN físico ou de software no seu data center. Você o configura com o endereço IP público do seu dispositivo VPN on-premises e o ASN (Autonomous System Number) do seu lado.

*   **Virtual Private Gateway (VGW) / Transit Gateway (TGW):** O gateway do lado da AWS. 
    *   O **VGW** é o gateway mais antigo, anexado a uma única VPC. É ideal para conectar uma única VPC à sua rede on-premises.
    *   O **TGW** é o hub de rede moderno, que permite que uma única conexão VPN forneça acesso a múltiplas VPCs anexadas ao TGW. É a solução preferida para ambientes multi-VPC.

*   **A Conexão VPN (VPN Connection):** O recurso que conecta o CGW ao VGW/TGW. Quando você cria uma conexão VPN, a AWS provisiona **dois túneis IPsec** em seu lado, terminando em dois endpoints públicos em Zonas de Disponibilidade diferentes. Isso é crucial para a redundância.

### Redundância e Alta Disponibilidade

O fato de a AWS provisionar dois túneis por padrão é crucial para a alta disponibilidade da sua conexão VPN.

*   **Redundância da AWS:** Se um dos endpoints da AWS falhar, o tráfego pode ser automaticamente roteado através do segundo túnel, mantendo a conectividade. Isso protege contra falhas de hardware ou software no lado da AWS.
*   **Sua Responsabilidade:** Para ter uma solução verdadeiramente HA, você também deve ter redundância do seu lado. Idealmente, você teria dois Customer Gateways (dispositivos VPN) no seu data center, cada um estabelecendo túneis para os dois endpoints da AWS (resultando em 4 túneis no total). Isso protege contra falhas no seu dispositivo VPN ou na sua conexão de internet.

*   **Roteamento:** A AWS VPN suporta dois tipos de roteamento para determinar qual tráfego deve passar pelo túnel:
    *   **Roteamento Estático:** Você especifica manualmente os blocos CIDR da sua rede on-premises e da sua VPC que devem ser roteados pelo túnel. Simples de configurar, mas menos dinâmico.
    *   **Roteamento Dinâmico (BGP):** Seu Customer Gateway estabelece uma sessão de BGP (Border Gateway Protocol) com o gateway da AWS através do túnel. Ele anuncia dinamicamente as rotas da sua rede para a AWS, e a AWS anuncia o CIDR da VPC de volta para você. Este é o método preferido para ambientes de produção, pois é mais robusto, se adapta automaticamente a mudanças na rede e permite o failover automático entre túneis.

## 2. Implementação de Site-to-Site VPN (Prática - 60 min)

Neste laboratório, vamos criar uma conexão Site-to-Site VPN. Como não temos um data center físico, usaremos uma segunda VPC e uma instância EC2 com um software de VPN (como o strongSwan) para **simular** o lado on-premises. Isso permitirá que você configure e valide a conexão VPN do lado da AWS.

### Cenário: Conectando um Escritório Remoto à VPC da AWS

Uma empresa possui sua infraestrutura principal na AWS e um pequeno escritório remoto com alguns servidores locais. Para garantir uma comunicação segura e privada entre o escritório e a VPC da AWS, eles decidem estabelecer uma VPN Site-to-Site. O escritório remoto será simulado por uma segunda VPC.

*   **VPC-A (Nuvem - Produção):** `10.10.0.0/16`. Terá um Virtual Private Gateway.
*   **VPC-B (Simula On-Premises - Escritório Remoto):** `192.168.0.0/16`. Terá uma instância EC2 atuando como nosso Customer Gateway (dispositivo VPN).
*   **Objetivo:** Estabelecer uma VPN entre as duas VPCs e permitir a comunicação privada entre instâncias em ambas as VPCs.

### Roteiro Prático

**Passo 1: Configurar a VPC "Nuvem" (VPC-A)**
1.  Crie a `VPC-A` (`10.10.0.0/16`) com uma sub-rede pública (ex: `10.10.1.0/24`).
2.  Crie um **Virtual Private Gateway (VGW)** e anexe-o à `VPC-A`.
3.  Vá para a tabela de rotas da sub-rede na `VPC-A` e, na aba **"Route Propagation"**, habilite a propagação a partir do seu VGW. Isso permitirá que a tabela aprenda as rotas da rede "on-premises" (VPC-B) automaticamente via BGP.

**Passo 2: Configurar a VPC "On-Premises" (VPC-B) e o "Customer Gateway"**
1.  Crie a `VPC-B` (`192.168.0.0/16`) e uma sub-rede pública (ex: `192.168.1.0/24`).
2.  Lance uma instância EC2 (Amazon Linux 2, `t2.micro`) nesta sub-rede. Chame-a de `On-Prem-Router`. Associe um Elastic IP a ela (este será o IP público do seu Customer Gateway).
3.  No Security Group desta instância, permita a entrada de `UDP porta 500` (IKE) e `UDP porta 4500` (IPsec NAT-T) de `0.0.0.0/0`, além do SSH para gerenciamento.
4.  **Instalar e Configurar strongSwan:** Este é o passo mais complexo e fora do escopo detalhado deste lab, mas é crucial para a simulação. Você precisaria instalar o strongSwan (`sudo yum install strongswan -y`) e configurar os arquivos `/etc/ipsec.conf` e `/etc/ipsec.secrets` com os parâmetros fornecidos pela AWS.

**Passo 3: Criar os Componentes da VPN na AWS**
1.  **Customer Gateway (CGW):**
    *   Vá para **VPN > Customer Gateways > Create customer gateway**.
    *   **Name:** `On-Prem-CGW`
    *   **Routing:** `Dynamic` (para usar BGP).
    *   **BGP ASN:** Um ASN privado para sua rede on-premises (ex: `65002`).
    *   **IP Address:** O **Elastic IP** da sua instância `On-Prem-Router`.
    *   Clique em **"Create customer gateway"**.
2.  **Conexão Site-to-Site VPN:**
    *   Vá para **VPN > Site-to-Site VPN Connections > Create VPN connection**.
    *   **Name:** `AWS-to-On-Prem-VPN`
    *   **Target Gateway Type:** `Virtual Private Gateway`, e selecione seu VGW (criado no Passo 1).
    *   **Customer Gateway:** `Existing`, e selecione seu `On-Prem-CGW`.
    *   **Routing Options:** `Dynamic (requires BGP)`.
    *   **Tunnel Options:** Deixe como padrão ou configure chaves pré-compartilhadas se desejar.
    *   Clique em **"Create VPN connection"**.

**Passo 4: Configurar o Lado On-Premises e Validar**
1.  **Baixar a Configuração:** Selecione a conexão VPN que você criou e clique em **"Download Configuration"**. Escolha o fornecedor `Generic` ou `strongSwan` para obter um arquivo de texto com todos os parâmetros necessários (IPs dos túneis da AWS, chaves pré-compartilhadas, configurações de BGP).
2.  **Aplicar a Configuração:** Use as informações do arquivo baixado para finalizar a configuração do strongSwan na sua instância `On-Prem-Router`. Isso envolve copiar as chaves pré-compartilhadas, os IPs dos túneis e configurar o BGP.
3.  **Iniciar a Conexão:** Inicie o serviço strongSwan (`sudo systemctl start strongswan`). Ele tentará estabelecer os túneis com os endpoints da AWS.
4.  **Validar:**
    *   No console da AWS, na sua conexão VPN, a aba **"Tunnel Details"** deve mostrar o status de pelo menos um túnel como **`UP`**.
    *   A aba **"Route Propagation"** na tabela de rotas da sua `VPC-A` deve mostrar o CIDR da rede on-premises (`192.168.0.0/16`) como uma rota aprendida.
    *   Lance uma instância na `VPC-A` e outra na `VPC-B`. Modifique seus SGs para permitir ICMP e SSH entre os CIDRs `10.10.0.0/16` e `192.168.0.0/16`.
    *   Faça ping entre as instâncias usando seus IPs privados. O ping deve funcionar, provando que o tráfego está sendo roteado e criptografado através do túnel VPN.

Este laboratório, embora complexo, demonstra o processo completo de estabelecimento de uma conexão segura entre a AWS e outra rede através da internet pública, uma habilidade essencial para cenários de nuvem híbrida.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Redundância é Fundamental:** Para ambientes de produção, sempre configure dois túneis VPN para cada conexão, e idealmente, dois dispositivos Customer Gateway no seu lado para garantir alta disponibilidade e resiliência a falhas.
*   **Roteamento Dinâmico (BGP):** Prefira o roteamento dinâmico com BGP em vez do estático. Ele é mais robusto, se adapta automaticamente a mudanças na rede e permite o failover automático entre túneis.
*   **Transit Gateway para Escalabilidade:** Para conectar sua rede on-premises a múltiplas VPCs na AWS, utilize o Transit Gateway em vez de múltiplos VGWs. Isso simplifica o roteamento e a gestão de conexões.
*   **Monitoramento:** Monitore o status dos túneis VPN e o tráfego que passa por eles usando CloudWatch. Configure alarmes para ser notificado sobre o status `DOWN` de um túnel.
*   **Segurança:** Embora a VPN criptografe o tráfego, ela não é um firewall. Use Security Groups e Network ACLs em suas VPCs para controlar o tráfego que entra e sai da sua rede on-premises.
*   **Planejamento de CIDR:** Certifique-se de que os blocos CIDR da sua rede on-premises e da sua VPC não se sobreponham. Isso é um requisito técnico para o roteamento funcionar corretamente.
*   **Documentação:** Documente detalhadamente a configuração da sua VPN, incluindo chaves pré-compartilhadas, IPs dos túneis e configurações de BGP.