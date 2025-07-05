# Módulo 2.1: Revisando Security Groups

**Tempo de Aula:** 45 minutos de teoria, 45 minutos de prática

## 1. Conceitos Fundamentais (Teoria Aprofundada)

### O Firewall como um Porteiro de Conexões
Um firewall é um sistema de segurança que atua como um porteiro, controlando o acesso a uma rede ou a um dispositivo. A característica mais importante que define o comportamento de um firewall é se ele é **stateful** ou **stateless**. 

Um firewall **stateful** (com estado) é um porteiro inteligente. Ele não apenas verifica quem está tentando entrar (as regras de entrada), mas também se lembra de quem já está dentro e de quem ele deixou sair. Quando alguém que ele deixou sair para almoçar volta, ele não precisa verificar suas credenciais novamente; ele sabe que a pessoa faz parte de uma "conversa" já aprovada. 

Tecnicamente, um firewall stateful mantém uma **tabela de estado** que rastreia todas as conexões de rede ativas. Quando um pacote de dados chega, ele primeiro verifica se o pacote pertence a uma conexão existente na tabela de estado. Se pertencer, ele é permitido automaticamente, sem passar pelo conjunto de regras principal. Isso torna a configuração muito mais simples, pois você só precisa definir as regras para o tráfego que **inicia** uma conexão.

### Security Groups: O Firewall Stateful da Instância
O **Security Group (SG)** da AWS é a implementação de um firewall stateful no nível da instância (especificamente, no nível da Interface de Rede Elástica - ENI). Ele é a primeira e mais importante camada de defesa que envolve diretamente seus recursos computacionais.

-   **Comportamento Stateful:** Se você criar uma regra de entrada para permitir tráfego na porta 443 (HTTPS), o tráfego de resposta do seu servidor web para o cliente (que ocorre em uma porta de origem aleatória e de alta numeração) é **automaticamente permitido**, independentemente das regras de saída. O SG "se lembra" da conexão HTTPS que ele permitiu.
-   **Lógica de Permissão:** SGs operam com uma lógica de "lista de permissão" (allow list). Eles negam todo o tráfego por padrão. Você só pode adicionar regras de `Allow`. Não há regras de `Deny`. Isso força uma mentalidade de segurança de **menor privilégio**: tudo é bloqueado, a menos que você o permita explicitamente.

## 2. Arquitetura e Casos de Uso

### Cenário Simples: Protegendo um Servidor Web Único
Um desenvolvedor lança um único servidor EC2 para hospedar um site. Ele precisa permitir o tráfego web e o acesso administrativo para si mesmo.

-   **Implementação:** Ele cria um único Security Group com três regras de entrada:
    1.  `Allow TCP port 80 from 0.0.0.0/0` (para HTTP)
    2.  `Allow TCP port 443 from 0.0.0.0/0` (para HTTPS)
    3.  `Allow TCP port 22 from 72.21.217.176/32` (SSH restrito ao seu IP específico)
-   **Justificativa:** Simples e eficaz. O SG protege a instância, permitindo apenas o tráfego necessário e bloqueando todo o resto (como tentativas de acesso a um banco de dados que possa estar rodando na mesma máquina).

### Cenário Corporativo Robusto: Microssegmentação e Confiança Zero (Zero Trust)
Uma empresa de SaaS está construindo uma aplicação de microsserviços. A filosofia de segurança da empresa é a **Confiança Zero (Zero Trust)**, que dita que nenhum ator, sistema ou rede, seja interno ou externo, deve ser confiável por padrão. A comunicação entre os microsserviços deve ser explicitamente autorizada.

-   **Implementação:** A equipe de segurança projeta uma estratégia de **microssegmentação** usando Security Groups. Cada microsserviço (ou camada de serviço) tem seu próprio SG.
    -   `sg-load-balancer`: Permite as portas 80/443 da internet.
    -   `sg-frontend-service`: Permite a porta 80 apenas da **origem `sg-load-balancer`**.
    -   `sg-auth-service`: Permite a porta 8080 apenas da **origem `sg-frontend-service`**.
    -   `sg-database-access-service`: Permite a porta 9000 apenas das origens `sg-frontend-service` e `sg-auth-service`.
    -   `sg-database`: Permite a porta 5432 apenas da **origem `sg-database-access-service`**.
-   **Justificativa:** Esta arquitetura implementa a Confiança Zero na rede. Os Security Groups atuam como um firewall distribuído que impõe a política de quem pode falar com quem. Se o serviço de front-end for comprometido, o invasor não poderá acessar diretamente o banco de dados; ele só poderá se comunicar com os serviços que o front-end está explicitamente autorizado a acessar. O uso de **referências de grupo** em vez de IPs torna essa arquitetura dinâmica e escalável. Se 100 novas instâncias de front-end forem adicionadas, nenhuma regra de firewall precisa ser alterada.

## 3. Melhores Práticas (AWS Well-Architected)

-   **Segurança:**
    -   **Princípio do Menor Privilégio:** Sempre comece com um SG vazio e adicione apenas as regras de permissão estritamente necessárias.
    -   **Use Referências de Grupo:** Prefira usar referências de Security Group como origem em vez de blocos CIDR para a comunicação interna da VPC. Isso é mais seguro e escalável.
    -   **Restrinja Portas de Gerenciamento:** Nunca permita acesso SSH (22) ou RDP (3389) de `0.0.0.0/0`. Restrinja sempre a um conjunto de IPs conhecidos (como o de um Bastion Host ou de uma VPN corporativa).
-   **Excelência Operacional:**
    -   **Nomenclatura e Tagueamento:** Dê nomes e descrições claras aos seus SGs e a cada regra. Isso é vital para a auditoria e o troubleshooting.
    -   **Gerenciamento com IaC:** Defina seus Security Groups como código (Terraform/CloudFormation) para garantir consistência e controle de versão.
-   **Confiabilidade:** Security Groups não causam problemas de confiabilidade se bem configurados. No entanto, uma regra incorreta é uma causa comum de interrupções de serviço.

## 4. Guia Prático (Laboratório)

O laboratório se concentra na implementação do cenário de microssegmentação. O aluno criará dois Security Groups, `Web-SG` e `DB-SG`, e configurará o `DB-SG` para permitir o tráfego da porta do banco de dados apenas da **origem `Web-SG`**. Este exercício prático é projetado para solidificar a compreensão do conceito de referências de grupo, que é a característica mais poderosa e importante dos Security Groups para a construção de arquiteturas seguras.
