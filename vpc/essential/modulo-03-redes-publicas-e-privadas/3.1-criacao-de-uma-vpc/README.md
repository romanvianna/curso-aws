# Módulo 3.1: Criação de uma VPC Customizada

**Tempo de Aula:** 30 minutos de teoria, 90 minutos de prática

## Pré-requisitos

*   Conhecimento dos conceitos fundamentais de VPC e seus componentes (Módulo 1.1).
*   Familiaridade com o console da AWS.
*   Noções básicas de endereçamento IP e CIDR.

## Objetivos

*   Compreender o design intencional da rede na AWS através da criação de VPCs customizadas.
*   Entender a distinção e o propósito das sub-redes públicas e privadas.
*   Aprender o processo passo a passo para criar uma VPC customizada, incluindo sub-redes, Internet Gateway e tabelas de rotas.
*   Discutir a importância da segmentação de rede para segurança e organização.
*   Realizar a criação de uma VPC customizada manualmente no console da AWS.

---

## 1. Conceitos Fundamentais: O Design Intencional da Rede (Teoria - 30 min)

A criação de uma VPC Customizada é o ponto onde passamos de um consumidor passivo de serviços de rede para um **arquiteto de rede intencional**. Em vez de aceitar uma configuração padrão (como a Default VPC), nós projetamos uma rede que atende aos requisitos específicos da nossa aplicação em termos de segurança, organização e escala. O princípio fundamental por trás de uma VPC Customizada é a **segmentação de rede**, que implementamos através da criação de camadas de sub-redes públicas e privadas.

### Sub-redes Públicas e Privadas: A Base da Segmentação

*   **Sub-rede Pública:** Uma sub-rede é definida como "pública" não por uma propriedade inerente, mas por uma decisão de roteamento. Sua característica definidora é que a tabela de rotas a ela associada contém uma **rota padrão (`0.0.0.0/0`) que aponta para um Internet Gateway (IGW)**. Esta sub-rede é a DMZ (Zona Desmilitarizada) da sua VPC, a única parte da sua rede que tem uma porta direta para a internet. É aqui que você coloca os recursos que precisam ser diretamente alcançáveis do exterior, como load balancers, servidores web de front-end ou bastion hosts.

*   **Sub-rede Privada:** Uma sub-rede é "privada" porque sua tabela de rotas associada **NÃO tem uma rota para o IGW**. Os recursos nesta sub-rede são, por padrão, invisíveis e inalcançáveis da internet. Eles podem se comunicar com outros recursos dentro da VPC (através da rota `local`), mas não podem iniciar conexões para a internet nem receber conexões de entrada. Esta é a camada segura onde residem seus componentes de back-end, como servidores de aplicação e, mais importante, bancos de dados.

O ato de criar uma VPC Customizada é o ato de aplicar o **Princípio do Menor Privilégio** à sua topologia de rede. Você nega todo o acesso externo por padrão (ao não ter uma rota para o IGW) e só o permite explicitamente para a camada de rede que absolutamente o exige.

## 2. Arquitetura e Casos de Uso: VPCs Customizadas em Cenários Reais

### Cenário Simples: Isolação de Banco de Dados para uma Startup

*   **Descrição:** Uma startup está evoluindo de um único servidor monolítico para uma arquitetura de dois níveis. Eles querem separar seu servidor web de seu banco de dados MySQL para melhorar a segurança.
*   **Implementação:** Eles criam uma nova VPC Customizada. Usando o "VPC Wizard" no console da AWS, eles selecionam o template "VPC with Public and Private Subnets". Isso cria automaticamente:
    *   Uma VPC (`10.0.0.0/16`).
    *   Uma sub-rede pública (`10.0.1.0/24`) com uma tabela de rotas apontando para um IGW.
    *   Uma sub-rede privada (`10.0.2.0/24`) com uma tabela de rotas que aponta para um NAT Gateway (para acesso de saída à internet para atualizações, por exemplo).
    *   Eles lançam o servidor web na sub-rede pública e a instância do banco de dados na sub-rede privada.
*   **Justificativa:** Este é o primeiro e mais importante passo para uma arquitetura segura. O banco de dados, o ativo mais valioso, é removido da exposição direta à internet, reduzindo drasticamente a superfície de ataque. A comunicação com o banco de dados só pode ocorrer a partir de dentro da VPC, controlada por Security Groups.

### Cenário Corporativo Robusto: Múltiplos Ambientes e Contas com Padronização

*   **Descrição:** Uma grande empresa de mídia precisa gerenciar ambientes de desenvolvimento, teste e produção para seu serviço de streaming, com uma estrita separação entre eles e padronização da infraestrutura.
*   **Implementação:** A infraestrutura é gerenciada inteiramente via Terraform (ou AWS CloudFormation). A empresa desenvolveu um **módulo Terraform de VPC** padronizado e reutilizável. 
    *   Quando a equipe de desenvolvimento precisa de um novo ambiente, eles invocam o módulo Terraform, passando variáveis como `environment=dev` e `cidr_block=10.10.0.0/16`. O módulo provisiona uma VPC completa e padronizada para desenvolvimento em sua própria conta AWS.
    *   O mesmo módulo é usado para provisionar os ambientes de teste e produção em suas respectivas contas AWS, com seus próprios blocos CIDR (`10.20.0.0/16` para teste, `10.30.0.0/16` para produção).
    *   Cada VPC criada pelo módulo já vem com uma estrutura de sub-redes Multi-AZ (pública, privada de aplicação, privada de dados), tabelas de rotas, NACLs e tags de governança, garantindo que todos os ambientes sigam o mesmo padrão de arquitetura aprovado pela equipe de segurança.
*   **Justificativa:** A criação de VPCs Customizadas é totalmente automatizada, garantindo consistência e conformidade. A separação por contas e por VPCs garante que os ambientes sejam completamente isolados uns dos outros. Um erro no ambiente de desenvolvimento não tem como impactar a rede de produção. O planejamento de CIDR evita sobreposições, permitindo que essas VPCs sejam conectadas no futuro através de um Transit Gateway, se necessário.

## 3. Guia Prático (Laboratório - 90 min)

O laboratório é um exercício prático e aprofundado que simula o trabalho de um arquiteto de nuvem. O aluno seguirá o fluxo de trabalho lógico para construir uma VPC do zero, manualmente, no console da AWS. Este processo manual e passo a passo é projetado para internalizar o propósito de cada componente e como eles se interconectam para criar uma rede segmentada e segura.

**Roteiro:**

1.  **Criar a VPC:**
    *   Navegue até o console da AWS > VPC > Your VPCs > Create VPC.
    *   **Name tag:** `Lab-Custom-VPC`.
    *   **IPv4 CIDR block:** `10.10.0.0/16`.
    *   Deixe as outras opções como padrão e clique em Create VPC.

2.  **Criar Sub-redes:**
    *   Navegue até Subnets > Create Subnet.
    *   **VPC ID:** Selecione `Lab-Custom-VPC`.
    *   **Sub-rede Pública (`Lab-Public-Subnet`):**
        *   **Name tag:** `Lab-Public-Subnet`.
        *   **Availability Zone:** Escolha `us-east-1a` (ou uma AZ na sua região).
        *   **IPv4 CIDR block:** `10.10.1.0/24`.
        *   Clique em Create Subnet.
    *   **Sub-rede Privada (`Lab-Private-Subnet`):**
        *   **Name tag:** `Lab-Private-Subnet`.
        *   **Availability Zone:** Escolha `us-east-1a` (a mesma da pública para simplicidade neste lab).
        *   **IPv4 CIDR block:** `10.10.2.0/24`.
        *   Clique em Create Subnet.

3.  **Criar e Anexar o Internet Gateway (IGW):**
    *   Navegue até Internet Gateways > Create internet gateway.
    *   **Name tag:** `Lab-IGW`.
    *   Clique em Create internet gateway.
    *   Após a criação, selecione o `Lab-IGW` e clique em Actions > Attach to VPC.
    *   Selecione `Lab-Custom-VPC` e clique em Attach internet gateway.

4.  **Criar e Configurar Tabela de Rotas Pública Customizada:**
    *   Navegue até Route Tables > Create route table.
    *   **Name tag:** `Lab-Public-RT`.
    *   **VPC:** Selecione `Lab-Custom-VPC`.
    *   Clique em Create route table.
    *   Selecione `Lab-Public-RT` e vá para a aba **"Routes"**.
    *   Clique em Edit routes > Add route.
    *   **Destination:** `0.0.0.0/0`.
    *   **Target:** Selecione `Internet Gateway` e escolha `Lab-IGW`.
    *   Clique em Save changes.

5.  **Associar Tabela de Rotas à Sub-rede Pública:**
    *   Na `Lab-Public-RT`, vá para a aba **"Subnet Associations"**.
    *   Clique em Edit subnet associations.
    *   Selecione `Lab-Public-Subnet` e clique em Save associations.

6.  **Verificar Tabela de Rotas da Sub-rede Privada:**
    *   Navegue até Route Tables.
    *   Identifique a tabela de rotas que está associada à `Lab-Private-Subnet`. Por padrão, ela será a tabela de rotas principal da VPC (marcada como "Main: Yes").
    *   Verifique suas rotas. Ela deve ter apenas a rota `local` (para o CIDR da VPC) e **NÃO** deve ter uma rota para o Internet Gateway. Isso garante que a sub-rede privada permaneça isolada da internet.

Este processo manual e passo a passo é projetado para internalizar o propósito de cada componente e como eles se interconectam para criar uma rede segmentada e segura.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Planejamento de CIDR:** Planeje seus blocos CIDR de VPC e sub-redes com antecedência. Escolha um bloco que não se sobreponha com outras redes (on-premises ou outras VPCs) para evitar problemas de conectividade futuros. Deixe espaço para crescimento.
*   **Multi-AZ:** Para alta disponibilidade, sempre crie sub-redes em pelo menos duas Zonas de Disponibilidade para cada camada (pública, privada). Isso permite que sua aplicação continue funcionando mesmo se uma AZ falhar.
*   **Princípio do Menor Privilégio na Rede:** Coloque apenas os recursos que *precisam* ser acessíveis da internet em sub-redes públicas. Todos os outros recursos (bancos de dados, servidores de aplicação de back-end, caches) devem ir para sub-redes privadas.
*   **Infraestrutura como Código (IaC):** Embora este laboratório seja manual para fins didáticos, em ambientes de produção, **sempre use IaC** (Terraform, CloudFormation) para definir e gerenciar suas VPCs. Isso garante repetibilidade, controle de versão, automação e reduz erros manuais.
*   **Nomenclatura Consistente:** Use uma convenção de nomenclatura clara e consistente para todos os seus recursos de VPC (ex: `projeto-ambiente-tipo-az`). Isso facilita a identificação e o gerenciamento.
*   **Tags:** Utilize tags de forma consistente em todos os seus recursos de VPC para facilitar a organização, o rastreamento de custos e a automação.
*   **Monitoramento:** Habilite VPC Flow Logs e CloudTrail para monitorar o tráfego de rede e as atividades da API na sua VPC, o que é crucial para segurança e troubleshooting.