# Módulo 3.1: Criação de uma VPC Customizada

**Tempo de Aula:** 30 minutos de teoria, 90 minutos de prática

## 1. Conceitos Fundamentais (Teoria Aprofundada)

### O Design Intencional da Rede
A criação de uma VPC Customizada é o ponto onde passamos de um consumidor passivo de serviços de rede para um **arquiteto de rede intencional**. Em vez de aceitar uma configuração padrão, nós projetamos uma rede que atende aos requisitos específicos da nossa aplicação em termos de segurança, organização e escala. O princípio fundamental por trás de uma VPC Customizada é a **segmentação de rede**, que implementamos através da criação de camadas de sub-redes públicas e privadas.

-   **Sub-rede Pública:** Uma sub-rede é definida como "pública" não por uma propriedade inerente, mas por uma decisão de roteamento. Sua característica definidora é que a tabela de rotas a ela associada contém uma **rota padrão (`0.0.0.0/0`) que aponta para um Internet Gateway (IGW)**. Esta sub-rede é a DMZ (Zona Desmilitarizada) da sua VPC, a única parte da sua rede que tem uma porta direta para a internet. É aqui que você coloca os recursos que precisam ser diretamente alcançáveis do exterior, como load balancers, servidores web de front-end ou bastion hosts.

-   **Sub-rede Privada:** Uma sub-rede é "privada" porque sua tabela de rotas associada **NÃO tem uma rota para o IGW**. Os recursos nesta sub-rede são, por padrão, invisíveis e inalcançáveis da internet. Eles podem se comunicar com outros recursos dentro da VPC (através da rota `local`), mas não podem iniciar conexões para a internet nem receber conexões de entrada. Esta é a camada segura onde residem seus componentes de back-end, como servidores de aplicação e, mais importante, bancos de dados.

O ato de criar uma VPC Customizada é o ato de aplicar o **Princípio do Menor Privilégio** à sua topologia de rede. Você nega todo o acesso externo por padrão (ao não ter uma rota para o IGW) e só o permite explicitamente para a camada de rede que absolutamente o exige.

## 2. Arquitetura e Casos de Uso

### Cenário Simples: Isolação de Banco de Dados
Uma startup está evoluindo de um único servidor monolítico para uma arquitetura de dois níveis. Eles querem separar seu servidor web de seu banco de dados MySQL.

-   **Implementação:** Eles criam uma nova VPC Customizada. Usando o "VPC Wizard" no console da AWS, eles selecionam o template "VPC with Public and Private Subnets". Isso cria automaticamente:
    -   Uma VPC (`10.0.0.0/16`).
    -   Uma sub-rede pública (`10.0.1.0/24`) com uma tabela de rotas apontando para um IGW.
    -   Uma sub-rede privada (`10.0.2.0/24`) com uma tabela de rotas que aponta para um NAT Gateway (para acesso de saída).
    -   Eles lançam o servidor web na sub-rede pública e a instância do banco de dados na sub-rede privada.
-   **Justificativa:** Este é o primeiro e mais importante passo para uma arquitetura segura. O banco de dados, o ativo mais valioso, é removido da exposição direta à internet, reduzindo drasticamente a superfície de ataque. A comunicação com o banco de dados só pode ocorrer a partir de dentro da VPC.

### Cenário Corporativo Robusto: Múltiplos Ambientes e Contas
Uma grande empresa de mídia precisa gerenciar ambientes de desenvolvimento, teste e produção para seu serviço de streaming, com uma estrita separação entre eles.

-   **Implementação:** A infraestrutura é gerenciada inteiramente via Terraform. A empresa desenvolveu um **módulo Terraform de VPC** padronizado e reutilizável. 
    -   Quando a equipe de desenvolvimento precisa de um novo ambiente, eles invocam o módulo Terraform, passando variáveis como `environment=dev` e `cidr_block=10.10.0.0/16`. O módulo provisiona uma VPC completa e padronizada para desenvolvimento em sua própria conta AWS.
    -   O mesmo módulo é usado para provisionar os ambientes de teste e produção em suas respectivas contas AWS, com seus próprios blocos CIDR (`10.20.0.0/16` para teste, `10.30.0.0/16` para produção).
    -   Cada VPC criada pelo módulo já vem com uma estrutura de sub-redes Multi-AZ (pública, privada de aplicação, privada de dados), tabelas de rotas, NACLs e tags de governança, garantindo que todos os ambientes sigam o mesmo padrão de arquitetura aprovado pela equipe de segurança.
-   **Justificativa:** A criação de VPCs Customizadas é totalmente automatizada, garantindo consistência e conformidade. A separação por contas e por VPCs garante que os ambientes sejam completamente isolados uns dos outros. Um erro no ambiente de desenvolvimento não tem como impactar a rede de produção. O planejamento de CIDR evita sobreposições, permitindo que essas VPCs sejam conectadas no futuro através de um Transit Gateway, se necessário.

## 3. Melhores Práticas (AWS Well-Architected)

-   **Segurança:** Sempre prefira VPCs Customizadas à VPC Padrão para qualquer carga de trabalho, mesmo as de desenvolvimento, para praticar bons hábitos de segurança desde o início.
-   **Excelência Operacional:** **SEMPRE** use Infraestrutura como Código (IaC) para definir suas VPCs. Uma VPC é uma infraestrutura complexa e fundamental; sua configuração nunca deve ser manual. O código serve como documentação e garante a repetibilidade.
-   **Confiabilidade:** Projete sua VPC para ser Multi-AZ desde o primeiro dia. Crie um conjunto de sub-redes (pública, privada, etc.) em cada Zona de Disponibilidade que você pretende usar.
-   **Otimização de Custos:** O planejamento cuidadoso do fluxo de tráfego é essencial. Se você tem dois componentes que se comunicam intensamente, colocá-los na mesma AZ pode economizar custos de transferência de dados, mas isso representa um trade-off com a resiliência. Esteja ciente dessa escolha.

## 4. Guia Prático (Laboratório)

O laboratório é um exercício prático e aprofundado que simula o trabalho de um arquiteto de nuvem. O aluno seguirá o fluxo de trabalho lógico para construir uma VPC do zero, manualmente, no console:
1.  **Criar a VPC:** Definir o contêiner de rede.
2.  **Criar Sub-redes:** Criar uma sub-rede pública e uma privada.
3.  **Criar e Anexar o IGW:** Criar a porta para a internet.
4.  **Criar e Configurar Tabelas de Rotas:** Criar uma tabela de rotas pública customizada e adicionar a rota `0.0.0.0/0` para o IGW.
5.  **Associar Tabelas de Rotas:** Associar a tabela de rotas pública à sub-rede pública.
6.  **Verificar:** Revisar a configuração para garantir que a sub-rede privada continua associada à tabela de rotas principal (privada).
Este processo manual e passo a passo é projetado para internalizar o propósito de cada componente e como eles se interconectam para criar uma rede segmentada e segura.
