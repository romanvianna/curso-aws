# Módulo 2.1: Revisando Security Groups

**Tempo de Aula:** 45 minutos de teoria, 45 minutos de prática

## Pré-requisitos

*   Conhecimento básico de redes TCP/IP (portas, protocolos).
*   Familiaridade com o conceito de instâncias EC2.
*   Compreensão do que é um firewall de rede.

## Objetivos

*   Compreender o Security Group (SG) como um firewall stateful em nível de instância.
*   Entender a diferença fundamental entre firewalls stateful e stateless.
*   Aprender a configurar regras de entrada (inbound) e saída (outbound) em Security Groups.
*   Dominar o uso de referências de Security Group para implementar microssegmentação e o princípio do menor privilégio.
*   Discutir as melhores práticas para o gerenciamento de Security Groups em ambientes de produção.

---

## 1. Conceitos Fundamentais: O Firewall como um Porteiro de Conexões (Teoria - 45 min)

Um firewall é um sistema de segurança que atua como um porteiro, controlando o acesso a uma rede ou a um dispositivo. A característica mais importante que define o comportamento de um firewall é se ele é **stateful** (com estado) ou **stateless** (sem estado).

### Firewall Stateful (Com Estado)

Um firewall **stateful** é um porteiro inteligente. Ele não apenas verifica quem está tentando entrar (as regras de entrada), mas também se lembra de quem já está dentro e de quem ele deixou sair. Quando alguém que ele deixou sair para almoçar volta, ele não precisa verificar suas credenciais novamente; ele sabe que a pessoa faz parte de uma "conversa" já aprovada.

Tecnicamente, um firewall stateful mantém uma **tabela de estado de conexão** que rastreia todas as sessões de rede ativas. Quando um pacote de dados chega, ele primeiro verifica se o pacote pertence a uma conexão existente na tabela de estado. Se pertencer, ele é permitido automaticamente, sem passar pelo conjunto de regras principal. Isso torna a configuração muito mais simples, pois você só precisa definir as regras para o tráfego que **inicia** uma conexão. O tráfego de resposta correspondente é automaticamente permitido.

### Security Groups: O Firewall Stateful da Instância na AWS

O **Security Group (SG)** da AWS é a implementação de um firewall stateful no nível da instância (especificamente, no nível da Interface de Rede Elástica - ENI). Ele é a primeira e mais importante camada de defesa que envolve diretamente seus recursos computacionais.

*   **Comportamento Stateful:** Se você criar uma regra de entrada para permitir tráfego na porta 443 (HTTPS), o tráfego de resposta do seu servidor web para o cliente (que ocorre em uma porta de origem aleatória e de alta numeração) é **automaticamente permitido**, independentemente das regras de saída. O SG "se lembra" da conexão HTTPS que ele permitiu. Da mesma forma, se você permitir tráfego de saída, o tráfego de resposta de entrada é permitido.
*   **Lógica de Permissão (Allow List):** SGs operam com uma lógica de "lista de permissão" (allow list). Eles negam todo o tráfego por padrão. Você só pode adicionar regras de `Allow`. **Não há regras de `Deny` explícitas em Security Groups**. Isso força uma mentalidade de segurança de **menor privilégio**: tudo é bloqueado, a menos que você o permita explicitamente.
*   **Escopo:** Um Security Group pode ser associado a uma ou mais instâncias EC2. Uma instância pode ter múltiplos Security Groups associados, e as regras de todos os SGs associados são efetivamente combinadas.

## 2. Arquitetura e Casos de Uso: Security Groups em Cenários Reais

### Cenário Simples: Protegendo um Servidor Web Único

*   **Descrição:** Um desenvolvedor lança um único servidor EC2 para hospedar um site simples. Ele precisa permitir o tráfego web (HTTP/HTTPS) para o público e o acesso administrativo (SSH) apenas para si mesmo.
*   **Implementação:** Ele cria um Security Group (`WebServer-SG`) e o associa à sua instância EC2. As regras de entrada seriam:
    1.  `Type: HTTP (80)`, `Source: 0.0.0.0/0` (Permite acesso HTTP de qualquer lugar).
    2.  `Type: HTTPS (443)`, `Source: 0.0.0.0/0` (Permite acesso HTTPS de qualquer lugar).
    3.  `Type: SSH (22)`, `Source: <SEU_IP_LOCAL>/32` (SSH restrito ao seu IP público específico).
*   **Justificativa:** Simples e eficaz. O SG protege a instância, permitindo apenas o tráfego necessário e bloqueando todo o resto (como tentativas de acesso a um banco de dados que possa estar rodando na mesma máquina). O tráfego de saída é permitido por padrão, o que é suficiente para este caso.

### Cenário Corporativo Robusto: Microssegmentação e Confiança Zero (Zero Trust)

*   **Descrição:** Uma empresa de SaaS está construindo uma aplicação de microsserviços complexa. A filosofia de segurança da empresa é a **Confiança Zero (Zero Trust)**, que dita que nenhum ator, sistema ou rede, seja interno ou externo, deve ser confiável por padrão. A comunicação entre os microsserviços deve ser explicitamente autorizada e restrita ao mínimo necessário.
*   **Implementação:** A equipe de segurança projeta uma estratégia de **microssegmentação** usando Security Groups. Cada microsserviço (ou camada de serviço) tem seu próprio SG, e as regras de comunicação são definidas usando **referências de Security Group**.
    *   `LoadBalancer-SG`: Permite as portas 80/443 da internet (`0.0.0.0/0`).
    *   `Frontend-SG`: Permite a porta 80 (ou 443) apenas da **origem `LoadBalancer-SG`**. (Isso significa que apenas o Load Balancer pode iniciar conexões com o Frontend).
    *   `AuthService-SG`: Permite a porta 8080 apenas da **origem `Frontend-SG`**. (Apenas o Frontend pode se comunicar com o serviço de autenticação).
    *   `Database-SG`: Permite a porta 3306 (MySQL) apenas da **origem `AuthService-SG`**. (Apenas o serviço de autenticação pode acessar o banco de dados).
*   **Justificativa:** Esta arquitetura implementa a Confiança Zero na rede. Os Security Groups atuam como um firewall distribuído que impõe a política de quem pode falar com quem. Se o serviço de front-end for comprometido, o invasor não poderá acessar diretamente o banco de dados; ele só poderá se comunicar com os serviços que o front-end está explicitamente autorizado a acessar. O uso de **referências de grupo** em vez de IPs torna essa arquitetura dinâmica e escalável. Se 100 novas instâncias de front-end forem adicionadas, nenhuma regra de firewall precisa ser alterada, pois a permissão é baseada no SG, não em IPs específicos.

## 3. Guia Prático (Laboratório - 45 min)

O laboratório se concentra na implementação do cenário de microssegmentação. O aluno criará dois Security Groups, `WebServer-SG` e `DBServer-SG`, e configurará o `DBServer-SG` para permitir o tráfego da porta do banco de dados apenas da **origem `WebServer-SG`**. Este exercício prático é projetado para solidificar a compreensão do conceito de referências de grupo, que é a característica mais poderosa e importante dos Security Groups para a construção de arquiteturas seguras.

**Roteiro:**

1.  **Criar Security Group para Servidor Web (`WebServer-SG`):**
    *   **Nome:** `WebServer-SG`
    *   **Descrição:** `Permite HTTP/HTTPS da internet e SSH do meu IP.`
    *   **VPC:** Sua VPC de laboratório.
    *   **Regras de Entrada (Inbound):**
        *   `Type: HTTP`, `Source: 0.0.0.0/0`
        *   `Type: HTTPS`, `Source: 0.0.0.0/0`
        *   `Type: SSH`, `Source: <SEU_IP_LOCAL>/32` (Use seu IP público atual).
    *   **Regras de Saída (Outbound):** `All traffic, 0.0.0.0/0` (Padrão, permite tudo para fora).

2.  **Criar Security Group para Servidor de Banco de Dados (`DBServer-SG`):**
    *   **Nome:** `DBServer-SG`
    *   **Descrição:** `Permite MySQL/Aurora apenas do WebServer-SG e SSH do meu IP.`
    *   **VPC:** Sua VPC de laboratório.
    *   **Regras de Entrada (Inbound):**
        *   `Type: MySQL/Aurora (3306)`, `Source: WebServer-SG` (Selecione o SG que você acabou de criar).
        *   `Type: SSH`, `Source: <SEU_IP_LOCAL>/32`.
    *   **Regras de Saída (Outbound):** `All traffic, 0.0.0.0/0`.

3.  **Lançar Instâncias EC2 (Opcional, para teste completo):**
    *   Lance uma instância EC2 (`t2.micro`, Amazon Linux 2) na sub-rede pública e associe o `WebServer-SG`.
    *   Lance outra instância EC2 (`t2.micro`, Amazon Linux 2) na sub-rede privada e associe o `DBServer-SG`.

4.  **Testar Conectividade:**
    *   Tente acessar a instância `DBServer` via SSH diretamente do seu IP local (deve ser bloqueado pelo `DBServer-SG` se você não adicionou seu IP diretamente).
    *   Tente acessar a instância `DBServer` via SSH da instância `WebServer` (deve ser bloqueado, pois o `WebServer-SG` não está na origem do SSH do `DBServer-SG`).
    *   Tente simular uma conexão de banco de dados da instância `WebServer` para a instância `DBServer` (ex: `telnet <IP_PRIVADO_DB> 3306`). Esta conexão deve ser permitida, pois o `DBServer-SG` permite tráfego do `WebServer-SG` na porta 3306.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Princípio do Menor Privilégio:** Sempre comece com um Security Group que nega todo o tráfego e adicione apenas as regras de permissão estritamente necessárias para a aplicação funcionar. Menos é mais em segurança.
*   **Use Referências de Security Group:** Para comunicação entre recursos dentro da mesma VPC, sempre use referências a outros Security Groups como origem ou destino, em vez de blocos CIDR. Isso torna suas regras mais dinâmicas, seguras e fáceis de gerenciar, especialmente em ambientes com Auto Scaling.
*   **Restrinja Portas de Gerenciamento:** Nunca permita acesso SSH (porta 22) ou RDP (porta 3389) de `0.0.0.0/0` (qualquer IP). Restrinja sempre a um conjunto de IPs conhecidos (ex: o IP do seu escritório, o CIDR da sua VPN corporativa, ou o Security Group de um Bastion Host).
*   **Nomenclatura e Descrição Claras:** Dê nomes descritivos aos seus Security Groups e adicione descrições claras a cada regra. Isso é vital para a auditoria, o troubleshooting e para que outros membros da equipe entendam o propósito de cada regra.
*   **Gerenciamento com IaC:** Defina seus Security Groups como código (usando Terraform, AWS CloudFormation ou AWS CDK). Isso garante consistência, controle de versão, facilita a revisão de código e a automação de implantações.
*   **Auditoria e Monitoramento:** Utilize VPC Flow Logs (Módulo 3.1) para monitorar o tráfego que é permitido ou negado pelos seus Security Groups. Isso ajuda a identificar tentativas de acesso não autorizado e a depurar problemas de conectividade. Monitore também as alterações nos Security Groups via AWS CloudTrail.
*   **Regras de Saída:** Embora os Security Groups sejam stateful e permitam o tráfego de resposta automaticamente, é uma boa prática revisar as regras de saída padrão (`Allow All`) e restringi-las se houver requisitos de segurança específicos (ex: permitir saída apenas para portas 80/443 para acesso à internet).