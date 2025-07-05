# Módulo 1.4: Site-to-Site VPN

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Entender os conceitos fundamentais de uma VPN IPsec, incluindo túneis, criptografia e troca de chaves (IKE).
- Analisar a arquitetura de uma conexão AWS Site-to-Site VPN, incluindo seus componentes.
- Projetar uma conexão VPN redundante e de alta disponibilidade.
- Implementar uma conexão Site-to-Site VPN entre uma VPC e uma rede on-premises simulada.

---

## 1. VPNs IPsec e Conectividade Híbrida (Teoria - 60 min)

Quando uma conexão dedicada como o Direct Connect não é viável (devido a custo, tempo ou localização), a maneira mais comum de estabelecer uma conectividade híbrida é através de uma **VPN (Virtual Private Network)**. Uma VPN cria um "túnel" seguro e criptografado através de uma rede não confiável (a internet pública), estendendo uma rede privada para além de seus limites físicos.

O padrão da indústria para conectar redes (site-to-site) é o **IPsec (Internet Protocol Security)**.

### Como uma VPN IPsec Funciona?

Uma VPN IPsec estabelece um túnel entre dois **gateways** (um na sua rede on-premises, chamado de **Customer Gateway**, e um na AWS, chamado de **Virtual Private Gateway** ou **Transit Gateway**). Todo o tráfego que passa entre as duas redes é criptografado.

O processo envolve duas fases principais:

1.  **Fase 1: IKE (Internet Key Exchange)**
    -   **Propósito:** Os dois gateways se autenticam e estabelecem um canal seguro para se comunicarem. Eles negociam os algoritmos de criptografia e hashing e geram chaves de sessão compartilhadas. Isso cria a **associação de segurança (Security Association - SA)** da Fase 1.

2.  **Fase 2: O Túnel IPsec**
    -   **Propósito:** Usando o canal seguro da Fase 1, os gateways estabelecem o túnel IPsec real através do qual os dados do usuário fluirão. Eles negociam os parâmetros para este túnel (a SA da Fase 2).
    -   **Encapsulamento:** Quando uma instância na sua VPC envia um pacote para um servidor on-premises, o gateway da AWS pega o pacote IP original, o **criptografa** e o **encapsula** dentro de um novo pacote IP. O endereço de destino deste novo pacote é o endereço IP público do seu Customer Gateway. O pacote viaja pela internet e, ao chegar, seu gateway o desencapsula, o descriptografa e o entrega ao servidor de destino final.

### Arquitetura da AWS Site-to-Site VPN

-   **Customer Gateway (CGW):** Um recurso na AWS que representa o seu dispositivo de VPN físico ou de software no seu data center. Você o configura com o endereço IP público do seu dispositivo.

-   **Virtual Private Gateway (VGW) / Transit Gateway (TGW):** O gateway do lado da AWS. 
    -   O **VGW** é o gateway mais antigo, anexado a uma única VPC.
    -   O **TGW** é o hub de rede moderno, que permite que uma única conexão VPN forneça acesso a múltiplas VPCs.

-   **A Conexão VPN (VPN Connection):** O recurso que conecta o CGW ao VGW/TGW. Quando você cria uma conexão VPN, a AWS provisiona **dois túneis IPsec** em seu lado, terminando em dois endpoints públicos em Zonas de Disponibilidade diferentes. 

### Redundância e Alta Disponibilidade

O fato de a AWS provisionar dois túneis por padrão é crucial para a alta disponibilidade.

-   **Redundância da AWS:** Se um dos endpoints da AWS falhar, o tráfego pode ser automaticamente roteado através do segundo túnel, mantendo a conectividade.
-   **Sua Responsabilidade:** Para ter uma solução verdadeiramente HA, você também deve ter redundância do seu lado. Idealmente, você teria dois Customer Gateways no seu data center, cada um estabelecendo túneis para os dois endpoints da AWS (resultando em 4 túneis no total).

-   **Roteamento:** A AWS VPN suporta dois tipos de roteamento para determinar qual tráfego deve passar pelo túnel:
    -   **Roteamento Estático:** Você especifica manualmente os blocos CIDR da sua rede on-premises.
    -   **Roteamento Dinâmico (BGP):** Seu Customer Gateway estabelece uma sessão de BGP (Border Gateway Protocol) com o gateway da AWS através do túnel. Ele anuncia dinamicamente as rotas da sua rede para a AWS, e a AWS anuncia o CIDR da VPC de volta para você. Este é o método preferido, pois é mais robusto e se adapta automaticamente a mudanças na rede.

---

## 2. Implementação de Site-to-Site VPN (Prática - 60 min)

Neste laboratório, vamos criar uma conexão Site-to-Site VPN. Como não temos um data center físico, usaremos uma segunda VPC e uma instância EC2 com um software de VPN (como o strongSwan) para **simular** o lado on-premises.

### Cenário

-   **VPC-A (Nuvem):** `10.10.0.0/16`. Terá um Virtual Private Gateway.
-   **VPC-B (Simula On-Premises):** `192.168.0.0/16`. Terá uma instância EC2 atuando como nosso Customer Gateway.
-   **Objetivo:** Estabelecer uma VPN entre as duas VPCs e permitir a comunicação privada.

### Roteiro Prático

**Passo 1: Configurar a VPC "Nuvem" (VPC-A)**
1.  Crie um **Virtual Private Gateway (VGW)** e anexe-o à `VPC-A`.
2.  Vá para a tabela de rotas da sub-rede na `VPC-A` e, na aba **"Route Propagation"**, habilite a propagação a partir do seu VGW. Isso permitirá que a tabela aprenda as rotas da rede "on-premises" automaticamente.

**Passo 2: Configurar a VPC "On-Premises" (VPC-B)**
1.  Crie a `VPC-B` e uma sub-rede pública.
2.  Lance uma instância EC2 (Amazon Linux 2) nesta sub-rede. Chame-a de `On-Prem-Router`. Associe um Elastic IP a ela.
3.  No Security Group desta instância, permita a entrada de `UDP porta 500` e `UDP porta 4500` (usadas pelo IPsec/IKE) de qualquer lugar, além do SSH para gerenciamento.
4.  Instale e configure um software de VPN, como o **strongSwan**, nesta instância. (Este é um passo complexo que envolve a edição de arquivos de configuração como `/etc/strongswan/ipsec.conf`).

**Passo 3: Criar os Componentes da VPN na AWS**
1.  **Customer Gateway (CGW):**
    -   Vá para **VPN > Customer Gateways > Create customer gateway**.
    -   **Name:** `On-Prem-CGW`
    -   **Routing:** `Dynamic` (para usar BGP).
    -   **BGP ASN:** Um ASN privado para sua rede on-premises (ex: `65002`).
    -   **IP Address:** O **Elastic IP** da sua instância `On-Prem-Router`.
2.  **Conexão Site-to-Site VPN:**
    -   Vá para **VPN > Site-to-Site VPN Connections > Create VPN connection**.
    -   **Name:** `AWS-to-On-Prem-VPN`
    -   **Target Gateway Type:** `Virtual Private Gateway`, e selecione seu VGW.
    -   **Customer Gateway:** `Existing`, e selecione seu `On-Prem-CGW`.
    -   **Routing Options:** `Dynamic (requires BGP)`.
    -   Clique em **"Create VPN connection"**.

**Passo 4: Configurar o Lado On-Premises e Validar**
1.  **Baixar a Configuração:** Selecione a conexão VPN que você criou e clique em **"Download Configuration"**. Escolha o fornecedor `Generic` ou `strongSwan` para obter um arquivo de texto com todos os parâmetros necessários (IPs dos túneis da AWS, chaves pré-compartilhadas, configurações de BGP).
2.  **Aplicar a Configuração:** Use as informações do arquivo baixado para finalizar a configuração do strongSwan na sua instância `On-Prem-Router`.
3.  **Iniciar a Conexão:** Inicie o serviço strongSwan. Ele tentará estabelecer os túneis com os endpoints da AWS.
4.  **Validar:**
    -   No console da AWS, na sua conexão VPN, a aba **"Tunnel Details"** deve mostrar o status de pelo menos um túnel como **`UP`**.
    -   A aba **"Static Routes"** ou as rotas aprendidas via BGP devem mostrar o CIDR da rede on-premises (`192.168.0.0/16`).
    -   Lance uma instância na `VPC-A` e outra na `VPC-B`. Modifique seus SGs para permitir ICMP entre os CIDRs `10.10.0.0/16` e `192.168.0.0/16`.
    -   Faça ping entre as instâncias usando seus IPs privados. O ping deve funcionar, provando que o tráfego está sendo roteado e criptografado através do túnel VPN.

Este laboratório, embora complexo, demonstra o processo completo de estabelecimento de uma conexão segura entre a AWS e outra rede através da internet pública, uma habilidade essencial para cenários de nuvem híbrida.
