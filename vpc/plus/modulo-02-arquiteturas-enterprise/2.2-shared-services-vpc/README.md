# Módulo 2.2: VPC de Serviços Compartilhados (Shared Services VPC)

**Tempo de Aula:** 60 minutos de teoria, 120 minutos de prática

## Objetivos

- Entender o padrão de arquitetura de uma VPC de Serviços Compartilhados.
- Analisar os benefícios de centralizar serviços de rede e segurança.
- Aprender a usar o AWS Resource Access Manager (RAM) para compartilhar sub-redes da VPC central com outras contas.
- Implementar uma arquitetura onde VPCs de aplicação (spokes) consomem serviços de uma VPC compartilhada (hub).

---

## 1. O Padrão de VPC de Serviços Compartilhados (Teoria - 60 min)

Em um ambiente multi-contas, muitas vezes existem serviços que precisam ser acessados por múltiplas cargas de trabalho em diferentes contas. Exemplos incluem:

-   **Serviços de Rede:** Endpoints de VPC de interface (para acessar APIs da AWS de forma privada), NAT Gateways, firewalls de rede.
-   **Serviços de Segurança:** Ferramentas de monitoramento, servidores de log centralizado, Active Directory para autenticação.
-   **Serviços de Ferramentas:** Repositórios de código (Git), servidores de CI/CD (Jenkins), repositórios de artefatos (Nexus/Artifactory).

A abordagem ingênua seria implantar esses serviços em cada VPC de aplicação. Isso leva a uma duplicação massiva de esforços, custos elevados e uma sobrecarga de gerenciamento.

### A Arquitetura Hub-and-Spoke para Serviços

O padrão **Shared Services VPC** resolve esse problema aplicando o modelo Hub-and-Spoke que já vimos, mas com um foco em serviços.

-   **O Hub (VPC de Serviços Compartilhados):**
    -   Você cria uma VPC central, geralmente em uma conta AWS dedicada à "Infraestrutura de Rede" ou "Serviços Compartilhados".
    -   Nesta VPC, você implanta todos os serviços comuns que precisam ser compartilhados. Por exemplo, você cria seus **VPC Interface Endpoints** aqui. Em vez de ter um endpoint para a API do EC2 em cada uma das 50 VPCs da sua organização, você tem **um único conjunto de endpoints** na VPC central.

-   **Os Spokes (VPCs de Aplicação):**
    -   São as VPCs nas contas de desenvolvimento e produção que hospedam as cargas de trabalho reais.

-   **A Conectividade:**
    -   Um **Transit Gateway** atua como o roteador central, conectando a VPC de Serviços Compartilhados (Hub) a todas as VPCs de Aplicação (Spokes).

### O Desafio: Como os Spokes Usam os Serviços do Hub?

Ok, as VPCs estão conectadas. Mas como uma instância na VPC de Aplicação A (em uma conta de desenvolvimento) pode usar um serviço que está na VPC de Serviços Compartilhados (em uma conta de rede)?

Se uma instância na VPC-A precisa acessar um endpoint na VPC compartilhada, ela precisa ter uma interface de rede (e um endereço IP) **dentro da mesma sub-rede do endpoint**. Mas a instância e o endpoint estão em VPCs e contas diferentes. Como resolver isso?

### A Solução: AWS Resource Access Manager (RAM)

O **AWS RAM** é o serviço que torna o padrão de Shared Services VPC possível. O RAM permite que você **compartilhe seus recursos da AWS com outras contas da AWS** dentro da sua organização.

No contexto de uma VPC compartilhada, o RAM é usado para uma finalidade muito específica e poderosa: **a conta de rede (proprietária da VPC de Serviços Compartilhados) pode compartilhar suas SUB-REDES com outras contas (as contas de aplicação)**.

-   **Como Funciona:**
    1.  Na conta de rede, você cria um **Compartilhamento de Recursos (Resource Share)** no RAM.
    2.  Você adiciona as **sub-redes** da sua VPC de Serviços Compartilhados a este compartilhamento.
    3.  Você especifica com quais **principais** (outras contas ou OUs inteiras) deseja compartilhar essas sub-redes.
    4.  Nas contas de aplicação, os administradores verão as sub-redes compartilhadas aparecerem em seu console da VPC. Eles não são os proprietários, mas podem **usá-las**.
    5.  Agora, um desenvolvedor na conta de aplicação pode **lançar uma instância EC2 diretamente em uma das sub-redes compartilhadas da VPC de Serviços Compartilhados**.

-   **O Resultado:** A instância do desenvolvedor agora reside na mesma VPC e sub-rede que os serviços compartilhados (como os VPC Endpoints). Ela recebe um IP do CIDR da VPC compartilhada e pode acessar os serviços diretamente, como se fossem locais. Todo o roteamento é simples e local à VPC de Serviços Compartilhados.

**Benefícios da Arquitetura:**
-   **Centralização e Custo:** Reduz drasticamente os custos ao ter um único conjunto de NAT Gateways, endpoints e firewalls, em vez de dezenas.
-   **Consistência e Segurança:** Garante que todas as cargas de trabalho usem o mesmo conjunto de serviços de rede e segurança aprovados e configurados centralmente.
-   **Separação de Responsabilidades:** A equipe de rede gerencia a VPC central e os serviços de rede. As equipes de aplicação gerenciam suas aplicações, mas as implantam em um ambiente de rede fornecido e governado centralmente.

---

## 2. Implementação de uma VPC Compartilhada (Prática - 120 min)

Este é um laboratório avançado que requer a configuração de um ambiente multi-contas.

### Cenário

-   **Conta A (Rede/Hub):** Possui a `Shared-Services-VPC` (`10.0.0.0/16`). Esta VPC contém sub-redes que serão compartilhadas.
-   **Conta B (Aplicação/Spoke):** Possui a `App-VPC` (`10.1.0.0/16`).
-   **Objetivo:** Compartilhar uma sub-rede da `Shared-Services-VPC` com a Conta B, e então lançar uma instância da Conta B nessa sub-rede compartilhada.

### Roteiro Prático

**Passo 1: Configurar as Contas e VPCs (Pré-requisitos)**
1.  Você precisará de duas contas AWS dentro da mesma **AWS Organization**.
2.  Na **Conta A (Rede)**, crie a `Shared-Services-VPC` com CIDR `10.0.0.0/16`. Crie uma sub-rede dentro dela chamada `Shared-Subnet-A` com CIDR `10.0.1.0/24`.
3.  Na **Conta B (Aplicação)**, crie a `App-VPC` com CIDR `10.1.0.0/16`.

**Passo 2: Habilitar o Compartilhamento no AWS Organizations**
1.  Faça login na **conta de gerenciamento** da sua organização.
2.  Navegue até o console do **AWS RAM**.
3.  No menu à esquerda, clique em **Settings**.
4.  Marque a caixa **"Enable sharing with AWS Organizations"**. Isso permite que você compartilhe recursos com OUs inteiras, não apenas com contas individuais.

**Passo 3: Criar o Compartilhamento de Recursos (na Conta A)**
1.  Faça login na **Conta A (Rede)**.
2.  Navegue até o console do **RAM** > **Resource shares** > **Create resource share**.
3.  **Name:** `VPC-Subnet-Share`
4.  **Resources:**
    -   **Select resource type:** `Subnets`.
    -   Marque a caixa de seleção ao lado da `Shared-Subnet-A`.
5.  **Principals:**
    -   Aqui você pode inserir o ID da Conta B ou, se você estruturou suas OUs, o ID da OU onde a Conta B reside.
6.  Clique em **"Create resource share"**.

**Passo 4: Aceitar o Compartilhamento e Lançar a Instância (na Conta B)**
1.  Faça login na **Conta B (Aplicação)**.
2.  Navegue até o console do **RAM** > **Shared with me** > **Resource shares**.
3.  Você verá o `VPC-Subnet-Share` com o status `Pending`. Selecione-o e clique em **"Accept resource share"**.
4.  O status mudará para `Active`.
5.  **A Mágica:** Agora, vá para o console da **VPC** na Conta B.
    -   Clique em **Subnets**. Você verá a `Shared-Subnet-A` listada, com a indicação de que o proprietário é a Conta A.
6.  **Lançar a Instância:**
    -   Vá para o console do **EC2** (ainda na Conta B).
    -   Clique em **"Launch instances"**.
    -   Ao configurar as **Network settings**, no dropdown de VPC, você agora verá a `Shared-Services-VPC` (da Conta A) como uma opção!
    -   Selecione a `Shared-Services-VPC` e, no dropdown de sub-rede, selecione a `Shared-Subnet-A`.
    -   Crie um novo Security Group (ele será criado na VPC compartilhada).
    -   Lance a instância.

**Passo 5: Validação**
1.  A instância lançada pela Conta B agora existe **dentro da VPC da Conta A**.
2.  Ela tem um endereço IP do bloco CIDR `10.0.1.0/24`.
3.  Se você tivesse VPC Endpoints ou um NAT Gateway na `Shared-Services-VPC`, esta instância poderia usá-los diretamente.
4.  Faça login na **Conta A** e vá para o console da VPC. Você verá a instância lançada pela Conta B listada como um recurso dentro da sua VPC.

Este laboratório demonstra um dos padrões de arquitetura de rede mais avançados e poderosos na AWS, permitindo a centralização de serviços, a redução de custos e uma governança de rede consistente em um ambiente multi-contas em escala.
