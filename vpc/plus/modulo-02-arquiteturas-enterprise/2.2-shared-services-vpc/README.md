# Módulo 2.2: VPC de Serviços Compartilhados (Shared Services VPC)

**Tempo de Aula:** 60 minutos de teoria, 120 minutos de prática

## Pré-requisitos

*   Conhecimento sólido de AWS Organizations e estratégia multi-contas (Módulo 2.1).
*   Familiaridade com VPCs, sub-redes, Security Groups e Transit Gateway (Módulo 1.2).
*   Compreensão dos conceitos de VPC Endpoints (Módulo 1.4 do curso Advanced).

## Objetivos

*   Entender o padrão de arquitetura de uma VPC de Serviços Compartilhados e seus benefícios em ambientes corporativos.
*   Analisar os benefícios de centralizar serviços de rede, segurança e ferramentas em uma VPC dedicada.
*   Aprender a usar o AWS Resource Access Manager (RAM) para compartilhar sub-redes da VPC central com outras contas-membro da organização.
*   Implementar uma arquitetura onde VPCs de aplicação (spokes) consomem serviços de uma VPC compartilhada (hub), demonstrando a conectividade e o isolamento.
*   Discutir as considerações de design e as melhores práticas para Shared Services VPCs.

---

## 1. O Padrão de VPC de Serviços Compartilhados (Teoria - 60 min)

Em um ambiente multi-contas, muitas vezes existem serviços que precisam ser acessados por múltiplas cargas de trabalho em diferentes contas. Exemplos incluem:

*   **Serviços de Rede:** Endpoints de VPC de interface (para acessar APIs da AWS de forma privada), NAT Gateways, firewalls de rede (ex: AWS Network Firewall), DNS centralizado (Route 53 Resolver Endpoints).
*   **Serviços de Segurança:** Ferramentas de monitoramento centralizado (ex: SIEM), servidores de log centralizado, Active Directory para autenticação e autorização, servidores de patch.
*   **Serviços de Ferramentas:** Repositórios de código (Git), servidores de CI/CD (Jenkins, GitLab), repositórios de artefatos (Nexus/Artifactory), ferramentas de automação.

Se cada VPC de aplicação implantasse e gerenciasse esses serviços de forma independente, isso levaria a uma duplicação massiva de esforços, custos elevados (ex: múltiplos NAT Gateways, múltiplos VPC Endpoints para o mesmo serviço) e uma sobrecarga de gerenciamento e auditoria.

### A Arquitetura Hub-and-Spoke para Serviços

O padrão **Shared Services VPC** resolve esse problema aplicando o modelo Hub-and-Spoke que já vimos, mas com um foco em serviços.

*   **O Hub (VPC de Serviços Compartilhados):**
    *   Você cria uma VPC central, geralmente em uma conta AWS dedicada à "Infraestrutura de Rede" ou "Serviços Compartilhados".
    *   Nesta VPC, você implanta todos os serviços comuns que precisam ser compartilhados. Por exemplo, você cria seus **VPC Interface Endpoints** aqui. Em vez de ter um endpoint para a API do EC2 em cada uma das 50 VPCs da sua organização, você tem **um único conjunto de endpoints** na VPC central, e todas as VPCs de aplicação podem acessá-los.

*   **Os Spokes (VPCs de Aplicação):**
    *   São as VPCs nas contas de desenvolvimento, teste e produção que hospedam as cargas de trabalho reais (aplicações, bancos de dados, etc.).

*   **A Conectividade:**
    *   Um **Transit Gateway** atua como o roteador central, conectando a VPC de Serviços Compartilhados (Hub) a todas as VPCs de Aplicação (Spokes). Isso permite o roteamento de tráfego entre as VPCs.

### O Desafio: Como os Spokes Usam os Serviços do Hub?

Ok, as VPCs estão conectadas via Transit Gateway. Mas como uma instância na VPC de Aplicação A (em uma conta de desenvolvimento) pode usar um serviço que está na VPC de Serviços Compartilhados (em uma conta de rede)?

Se uma instância na VPC-A precisa acessar um endpoint na VPC compartilhada, ela precisa ter uma interface de rede (e um endereço IP) **dentro da mesma sub-rede do endpoint**. Mas a instância e o endpoint estão em VPCs e contas diferentes. Como resolver isso?

### A Solução: AWS Resource Access Manager (RAM)

O **AWS RAM** é o serviço que torna o padrão de Shared Services VPC possível. O RAM permite que você **compartilhe seus recursos da AWS com outras contas da AWS** dentro da sua organização ou com OUs inteiras.

No contexto de uma VPC compartilhada, o RAM é usado para uma finalidade muito específica e poderosa: **a conta de rede (proprietária da VPC de Serviços Compartilhados) pode compartilhar suas SUB-REDES com outras contas (as contas de aplicação)**.

*   **Como Funciona:**
    1.  Na conta de rede, você cria um **Compartilhamento de Recursos (Resource Share)** no RAM.
    2.  Você adiciona as **sub-redes** da sua VPC de Serviços Compartilhados a este compartilhamento.
    3.  Você especifica com quais **principais** (outras contas ou OUs inteiras) deseja compartilhar essas sub-redes.
    4.  Nas contas de aplicação, os administradores verão as sub-redes compartilhadas aparecerem em seu console da VPC. Eles não são os proprietários, mas podem **usá-las**.
    5.  Agora, um desenvolvedor na conta de aplicação pode **lançar uma instância EC2 diretamente em uma das sub-redes compartilhadas da VPC de Serviços Compartilhados**.

*   **O Resultado:** A instância do desenvolvedor agora reside na mesma VPC e sub-rede que os serviços compartilhados (como os VPC Endpoints). Ela recebe um IP do CIDR da VPC compartilhada e pode acessar os serviços diretamente, como se fossem locais. Todo o roteamento é simples e local à VPC de Serviços Compartilhados. Isso é conhecido como **VPC Sharing**.

**Benefícios da Arquitetura Shared Services VPC:**

*   **Centralização e Custo:** Reduz drasticamente os custos ao ter um único conjunto de NAT Gateways, endpoints e firewalls, em vez de dezenas de duplicações em cada VPC de aplicação.
*   **Consistência e Segurança:** Garante que todas as cargas de trabalho usem o mesmo conjunto de serviços de rede e segurança aprovados e configurados centralmente, aplicando políticas de forma consistente.
*   **Separação de Responsabilidades:** A equipe de rede gerencia a VPC central e os serviços de rede. As equipes de aplicação gerenciam suas aplicações, mas as implantam em um ambiente de rede fornecido e governado centralmente, aumentando a agilidade e reduzindo a complexidade para os desenvolvedores.
*   **Simplificação do Roteamento:** O tráfego para serviços compartilhados não precisa atravessar o Transit Gateway, pois a instância está na mesma VPC que o serviço.

## 2. Implementação de uma VPC Compartilhada (Prática - 120 min)

Este é um laboratório avançado que requer a configuração de um ambiente multi-contas e a utilização do AWS Organizations. Ele simula um cenário corporativo onde serviços de rede são centralizados.

### Cenário: Centralização de Serviços de Rede para Aplicações

Uma empresa deseja centralizar seus serviços de rede, como VPC Endpoints para serviços AWS e NAT Gateways, em uma VPC dedicada (`Shared-Services-VPC`) em uma conta de rede (`Account-Network`). As equipes de desenvolvimento e produção, que operam em contas separadas (`Account-Dev`, `Account-Prod`), precisam consumir esses serviços. Usaremos o AWS RAM para compartilhar sub-redes da `Shared-Services-VPC` com as contas de aplicação.

*   **Conta A (Rede/Hub):** Possui a `Shared-Services-VPC` (`10.0.0.0/16`). Esta VPC contém sub-redes que serão compartilhadas.
*   **Conta B (Aplicação/Spoke):** Possui a `App-VPC` (`10.1.0.0/16`).
*   **Objetivo:** Compartilhar uma sub-rede da `Shared-Services-VPC` com a Conta B, e então lançar uma instância da Conta B nessa sub-rede compartilhada para demonstrar o acesso aos serviços centralizados.

### Roteiro Prático

**Passo 1: Configurar as Contas e VPCs (Pré-requisitos)**
1.  Você precisará de duas contas AWS dentro da mesma **AWS Organization**. Uma será a **Conta A (Rede)** e a outra a **Conta B (Aplicação)**. (Se você seguiu o Módulo 2.1, pode usar a conta de gerenciamento como Conta A e a `Sandbox-Account` como Conta B).
2.  Faça login na **Conta A (Rede)**. Crie a `Shared-Services-VPC` com CIDR `10.0.0.0/16`. Crie uma sub-rede dentro dela chamada `Shared-Subnet-A` com CIDR `10.0.1.0/24` (e um Internet Gateway e tabela de rotas pública para ela, se necessário).
3.  Faça login na **Conta B (Aplicação)**. Crie a `App-VPC` com CIDR `10.1.0.0/16` (apenas para ter uma VPC na conta, não será usada diretamente para o compartilhamento).

**Passo 2: Habilitar o Compartilhamento no AWS Organizations**
*   Este passo é crucial para permitir o compartilhamento de recursos com contas dentro da sua organização.
1.  Faça login na **conta de gerenciamento** da sua organização.
2.  Navegue até o console do **AWS RAM**.
3.  No menu à esquerda, clique em **Settings**.
4.  Marque a caixa **"Enable sharing with AWS Organizations"**. Isso permite que você compartilhe recursos com OUs inteiras ou com contas específicas dentro da sua organização, sem a necessidade de aceitação manual para cada compartilhamento.

**Passo 3: Criar o Compartilhamento de Recursos (na Conta A - Rede)**
1.  Faça login na **Conta A (Rede)**.
2.  Navegue até o console do **RAM** > **Resource shares** > **Create resource share**.
3.  **Name:** `VPC-Subnet-Share`
4.  **Resources:**
    *   **Select resource type:** `Subnets`.
    *   Marque a caixa de seleção ao lado da `Shared-Subnet-A` (a sub-rede que você criou na `Shared-Services-VPC`).
5.  **Principals:**
    *   Aqui você pode inserir o ID da Conta B (a conta de aplicação) ou, se você estruturou suas OUs, o ID da OU onde a Conta B reside (ex: a OU `Development`).
6.  Clique em **"Create resource share"**.

**Passo 4: Aceitar o Compartilhamento e Lançar a Instância (na Conta B - Aplicação)**
1.  Faça login na **Conta B (Aplicação)**.
2.  Navegue até o console do **RAM** > **Shared with me** > **Resource shares**.
3.  Você verá o `VPC-Subnet-Share` com o status `Pending`. Selecione-o e clique em **"Accept resource share"**. (Se você compartilhou com uma OU, este passo pode não ser necessário, pois a aceitação é automática).
4.  O status mudará para `Active`.
5.  **A Mágica:** Agora, vá para o console da **VPC** na Conta B.
    *   Clique em **Subnets**. Você verá a `Shared-Subnet-A` listada, com a indicação de que o proprietário é a Conta A. Isso confirma que a sub-rede foi compartilhada com sucesso.
6.  **Lançar a Instância na Sub-rede Compartilhada:**
    *   Vá para o console do **EC2** (ainda na Conta B).
    *   Clique em **"Launch instances"**.
    *   Ao configurar as **Network settings**, no dropdown de VPC, você agora verá a `Shared-Services-VPC` (da Conta A) como uma opção!
    *   Selecione a `Shared-Services-VPC` e, no dropdown de sub-rede, selecione a `Shared-Subnet-A`.
    *   Crie um novo Security Group (ele será criado na VPC compartilhada, mas gerenciado pela Conta B).
    *   Lance a instância (ex: `t2.micro`, Amazon Linux 2).

**Passo 5: Validação**
1.  A instância lançada pela Conta B agora existe **dentro da VPC da Conta A**.
2.  Ela tem um endereço IP do bloco CIDR `10.0.1.0/24` (da `Shared-Subnet-A`).
3.  Se você tivesse VPC Endpoints ou um NAT Gateway na `Shared-Services-VPC` (Conta A), esta instância (da Conta B) poderia usá-los diretamente, pois está na mesma VPC.
4.  Faça login na **Conta A (Rede)** e vá para o console da VPC. Você verá a instância lançada pela Conta B listada como um recurso dentro da sua VPC, mas com o proprietário sendo a Conta B.

Este laboratório demonstra um dos padrões de arquitetura de rede mais avançados e poderosos na AWS, permitindo a centralização de serviços, a redução de custos e uma governança de rede consistente em um ambiente multi-contas em escala.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Use VPC Sharing para Centralizar Serviços:** Este padrão é ideal para centralizar serviços de rede (NAT Gateways, VPC Endpoints, AWS Network Firewall), serviços de segurança (Active Directory, SIEM) e ferramentas (CI/CD, repositórios de artefatos) que precisam ser acessados por múltiplas VPCs e contas.
*   **Transit Gateway para Conectividade Inter-VPC:** Combine o VPC Sharing com o Transit Gateway. O TGW conecta as VPCs de aplicação entre si e à VPC de serviços compartilhados, enquanto o VPC Sharing permite que as instâncias de aplicação residam na mesma VPC que os serviços compartilhados para acesso direto.
*   **Planejamento de IP:** O planejamento de endereçamento IP é ainda mais crítico em uma arquitetura de VPC compartilhada. Certifique-se de que os CIDRs das VPCs de aplicação e da VPC de serviços compartilhados não se sobreponham.
*   **Segurança e IAM:** Gerencie cuidadosamente as permissões IAM. A conta proprietária da VPC compartilhada controla a rede, enquanto as contas consumidoras controlam os recursos que lançam nas sub-redes compartilhadas. Use políticas IAM para definir o que cada conta pode fazer.
*   **Monitoramento e Logs:** Centralize os VPC Flow Logs e os logs de acesso de serviços na conta de segurança/log para ter uma visão completa do tráfego e das atividades em toda a organização.
*   **Automação:** Automatize a criação e o compartilhamento de VPCs e sub-redes usando Infraestrutura como Código (Terraform, CloudFormation) e AWS Organizations.
*   **Considerações de Custo:** O tráfego dentro da VPC compartilhada é gratuito. O tráfego que atravessa o Transit Gateway tem custo. O VPC Sharing ajuda a otimizar custos ao reduzir a necessidade de múltiplos NAT Gateways e VPC Endpoints.