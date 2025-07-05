# Módulo 2.1: ACLs e Security Groups Avançados

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento fundamental de redes TCP/IP (portas, protocolos).
*   Familiaridade com os conceitos básicos de VPC, sub-redes e roteamento.
*   Compreensão inicial de Security Groups e Network ACLs (NACLs).

## Objetivos

*   Compreender o princípio de segurança de **Defesa em Profundidade (Defense in Depth)**.
*   Aplicar este princípio usando Security Groups e Network ACLs como camadas de segurança complementares.
*   Analisar o fluxo de pacotes através das camadas de segurança da VPC, entendendo a ordem de avaliação.
*   Implementar uma arquitetura de segurança multicamada para uma aplicação web, validando o isolamento entre as camadas.
*   Discutir cenários avançados de uso e melhores práticas para SGs e NACLs.

---

## 1. O Modelo de Defesa em Profundidade (Teoria - 60 min)

**Defesa em Profundidade** é uma estratégia de segurança da informação que, em vez de depender de uma única barreira, utiliza uma série de mecanismos de segurança em camadas. A intenção é que, se uma camada for contornada por um invasor, a próxima camada possa conter ou, pelo menos, retardar o ataque. É o princípio de não colocar todos os ovos na mesma cesta.

Em uma rede, isso significa ir além do tradicional "firewall de perímetro". Em vez de ter apenas um muro forte ao redor do castelo, colocamos guardas em cada portão, portas trancadas em cada sala e um cofre para os bens mais preciosos. 

Na AWS VPC, as duas principais camadas de firewall de rede que nos permitem implementar a Defesa em Profundidade são as **Network ACLs** e os **Security Groups**.

### O Fluxo de um Pacote e as Camadas de Defesa

Vamos seguir a jornada de um pacote de dados de entrada, vindo da internet para uma instância EC2 em uma sub-rede. É crucial entender a ordem em que as regras são avaliadas:

1.  **Internet Gateway (IGW):** O pacote entra na VPC.
2.  **Tabela de Rotas da VPC:** O roteador da VPC direciona o pacote para a sub-rede de destino.
3.  **CAMADA 1: Network ACL (NACL) - O Muro do Bairro (Nível da Sub-rede)**
    *   O pacote chega à fronteira da sub-rede. A Network ACL associada a essa sub-rede é a primeira a inspecioná-lo.
    *   A NACL é **stateless** (sem estado): ela não rastreia o estado das conexões. Para cada requisição e sua resposta, ela avalia as regras de entrada e saída independentemente.
    *   Verifica suas regras em **ordem numérica crescente** (da menor para a maior). A primeira regra que corresponde ao tráfego é aplicada, e nenhuma outra regra é avaliada.
    *   Possui regras de `ALLOW` e `DENY` explícitas. Há uma regra de `DENY ALL` implícita no final de cada NACL customizada.
    *   Se houver uma regra de `DENY` que corresponda ao pacote, ele é **descartado imediatamente**. Fim da história. Ele nunca chega à instância.
    *   Se houver uma regra de `ALLOW` correspondente, o pacote tem permissão para entrar na sub-rede.

4.  **CAMADA 2: Security Group (SG) - A Porta da Casa (Nível da Instância/ENI)**
    *   O pacote agora chegou à interface de rede (ENI) da instância EC2. O Security Group associado a essa ENI o inspeciona.
    *   O SG é **stateful** (com estado): ele rastreia o estado das conexões. Se você permite o tráfego de entrada, o tráfego de resposta correspondente é automaticamente permitido na saída, e vice-versa, sem a necessidade de uma regra explícita de saída.
    *   Avalia **todas** as suas regras de `ALLOW`. Se houver uma regra que permita o tráfego (com base na origem, porta e protocolo), o pacote é entregue ao sistema operacional da instância.
    *   Não possui regras de `DENY` explícitas. Se nenhuma regra de `ALLOW` corresponder, o pacote é **descartado implicitamente**.

5.  **CAMADA 3: Firewall do Host (O Segurança Dentro de Casa - Nível do Sistema Operacional)**
    *   Mesmo que o pacote passe pela NACL e pelo SG, ainda pode haver um firewall rodando no próprio sistema operacional da instância (como `iptables` no Linux, `firewalld` ou o Firewall do Windows). Esta é uma terceira camada de defesa que você mesmo gerencia e que oferece a proteção mais granular.

### Papéis Estratégicos das Camadas

Como as duas camadas têm características diferentes, elas devem ser usadas para propósitos estratégicos diferentes:

*   **Network ACLs (Stateless, `Allow`/`Deny`, Nível da Sub-rede):**
    *   **Função:** Ferramenta de força bruta, controle de perímetro para sub-redes inteiras. Ideal para regras amplas e de alta confiança.
    *   **Estratégia:** Use-as com moderação para fins específicos, pois a natureza stateless exige regras de entrada e saída para o tráfego de resposta, o que pode ser complexo. São excelentes para:
        *   **Blacklisting:** Bloquear explicitamente endereços IP maliciosos conhecidos em nível de sub-rede. Uma regra de `DENY` na NACL é a maneira mais eficiente de fazer isso, pois o tráfego é descartado antes de chegar às instâncias.
        *   **Whitelisting de Perímetro:** Em um ambiente de alta segurança, você pode configurar a NACL para negar tudo por padrão e permitir explicitamente o tráfego apenas de redes confiáveis (ex: o IP do seu escritório ou VPN corporativa).
        *   **Controle de Tráfego entre Tiers:** Em arquiteturas multi-tier, NACLs podem ser usadas para garantir que o tráfego entre sub-redes (ex: Web para App, App para DB) siga um fluxo estrito, adicionando uma camada extra de segurança além dos Security Groups.

*   **Security Groups (Stateful, Apenas `Allow`, Nível da Instância):**
    *   **Função:** Ferramenta de precisão, controle de acesso à aplicação. Esta deve ser sua principal ferramenta de firewall no dia a dia.
    *   **Estratégia:** A abordagem é sempre o **Princípio do Menor Privilégio**. Permita apenas o tráfego estritamente necessário.
        *   **Microssegmentação:** Crie SGs granulares para cada camada ou serviço da sua aplicação (ex: `web-sg`, `app-sg`, `db-sg`).
        *   **Referências de Grupo:** Use referências de SG como origem/destino para definir as regras de comunicação entre as camadas. Isso é mais seguro e escalável do que usar blocos CIDR, pois o SG se adapta dinamicamente às mudanças de IPs das instâncias.
        *   **Controle de Acesso a Portas Específicas:** Ideal para permitir acesso a portas de aplicação (80, 443, 8080, 3306) apenas de fontes autorizadas.

---

## 2. Implementação de Arquitetura de Segurança Multicamada (Prática - 60 min)

Neste laboratório, vamos aplicar a Defesa em Profundidade, configurando uma NACL e Security Groups para proteger uma aplicação de 3 camadas (Web, App, DB), simulando um ambiente corporativo.

### Cenário: Aplicação de E-commerce de 3 Camadas

Uma empresa de e-commerce possui uma aplicação dividida em três camadas lógicas, cada uma em sua própria sub-rede:
*   **Camada Web:** Servidores web (Nginx/Apache) em uma sub-rede pública, acessíveis da internet.
*   **Camada de Aplicação:** Servidores de aplicação (Node.js/Java) em uma sub-rede privada, acessíveis apenas pela camada Web.
*   **Camada de Banco de Dados:** Servidores de banco de dados (MySQL/PostgreSQL) em uma sub-rede ainda mais privada, acessíveis apenas pela camada de Aplicação.

Nosso objetivo é configurar Security Groups para controle de acesso granular entre as camadas e uma NACL para a sub-rede do banco de dados, adicionando uma camada extra de proteção de perímetro.

### Roteiro Prático

**Passo 1: Configurar os Security Groups (A Guarda Pessoal - Nível da Instância)**

Assumimos que você já tem uma VPC com sub-redes `Subnet-Web` (Pública), `Subnet-App` (Privada), `Subnet-DB` (Privada).

1.  **`Web-SG` (para instâncias da Camada Web):**
    *   **Regra de Entrada (Inbound):**
        *   `Type: HTTP (80)`, `Source: 0.0.0.0/0` (Permite acesso web da internet).
        *   `Type: HTTPS (443)`, `Source: 0.0.0.0/0` (Permite acesso web seguro da internet).
        *   `Type: SSH (22)`, `Source: <SEU_IP_LOCAL>/32` (Permite acesso SSH apenas do seu IP).
    *   **Regra de Saída (Outbound):**
        *   `Type: All Traffic`, `Destination: 0.0.0.0/0` (Permite acesso a internet para atualizações, etc.).
        *   `Type: TCP`, `Port Range: 8080`, `Destination: App-SG` (Permite que a camada Web se comunique com a camada de Aplicação na porta 8080).

2.  **`App-SG` (para instâncias da Camada de Aplicação):**
    *   **Regra de Entrada (Inbound):**
        *   `Type: TCP`, `Port Range: 8080`, `Source: Web-SG` (Permite acesso apenas do Security Group da camada Web).
        *   `Type: SSH (22)`, `Source: <SEU_IP_LOCAL>/32` (Para gerenciamento, se necessário).
    *   **Regra de Saída (Outbound):**
        *   `Type: All Traffic`, `Destination: 0.0.0.0/0` (Para acesso a APIs externas, atualizações, etc. - via NAT Gateway se em sub-rede privada).
        *   `Type: MySQL/Aurora (3306)`, `Destination: DB-SG` (Permite que a camada de Aplicação se comunique com a camada de Banco de Dados na porta 3306).

3.  **`DB-SG` (para instâncias da Camada de Banco de Dados):**
    *   **Regra de Entrada (Inbound):**
        *   `Type: MySQL/Aurora (3306)`, `Source: App-SG` (Permite acesso apenas do Security Group da camada de Aplicação).
        *   `Type: SSH (22)`, `Source: <SEU_IP_LOCAL>/32` (Para gerenciamento, se necessário).
    *   **Regra de Saída (Outbound):**
        *   `Type: All Traffic`, `Destination: 0.0.0.0/0` (Se o DB precisar de acesso a repositórios de pacotes, etc. - via NAT Gateway).

**Passo 2: Configurar a Network ACL da Camada de Dados (O Muro do Cofre - Nível da Sub-rede)**

Vamos criar uma NACL extra-restritiva para a sub-rede do banco de dados (`Subnet-DB`). Lembre-se que NACLs são stateless e precisam de regras para tráfego de entrada e saída.

1.  Crie uma nova NACL: `Name: DB-NACL`, na sua `Lab-VPC`.
2.  **Edite as Regras de Entrada (Inbound Rules):**
    *   **Regra 100:** `ALLOW TCP port 3306` from `CIDR da Subnet-App` (ex: `10.0.2.0/24`). (Permite a conexão inicial da camada de aplicação).
    *   **Regra 110:** `ALLOW TCP ports 1024-65535` from `CIDR da Subnet-App` (ex: `10.0.2.0/24`). (Permite o tráfego de resposta da camada de banco de dados de volta para a camada de aplicação. As portas efêmeras são usadas para as respostas).
    *   **Regra 120:** `ALLOW TCP port 22` from `<SEU_IP_LOCAL>/32` (Se você precisar de acesso SSH direto à sub-rede do DB para troubleshooting).
    *   `*` (Asterisco): Regra de `DENY ALL` implícita no final.

3.  **Edite as Regras de Saída (Outbound Rules):**
    *   **Regra 100:** `ALLOW TCP port 3306` to `CIDR da Subnet-App` (ex: `10.0.2.0/24`). (Permite o tráfego de resposta do DB para a App, se a conexão foi iniciada pelo DB - raro, mas possível).
    *   **Regra 110:** `ALLOW TCP ports 1024-65535` to `CIDR da Subnet-App` (ex: `10.0.2.0/24`). (Permite o tráfego de resposta da camada de banco de dados de volta para a camada de aplicação).
    *   **Regra 120:** `ALLOW TCP port 22` to `<SEU_IP_LOCAL>/32` (Para respostas SSH).
    *   `*` (Asterisco): Regra de `DENY ALL` implícita no final.

4.  **Associe a `DB-NACL` à `Subnet-DB`:**
    *   Vá para a aba "Subnet associations" da `DB-NACL` e associe-a à sua sub-rede de banco de dados.

**Passo 3: Adicionar uma Regra de Negação Explícita (Blacklisting) na NACL Pública**

Vamos supor que o endereço IP `203.0.113.5` é um atacante conhecido ou um IP que deve ser bloqueado por política corporativa.

1.  Vá para a NACL associada à sua **sub-rede pública** (`Subnet-Web`).
2.  Adicione uma nova regra de **entrada** com um número baixo (para garantir que seja avaliada primeiro):
    *   **Rule Number:** `90`
    *   **Type:** `All Traffic`
    *   **Source:** `203.0.113.5/32`
    *   **Allow/Deny:** **DENY**
3.  Salve a regra. Agora, este IP está bloqueado no perímetro da sua VPC, antes mesmo de chegar ao Security Group.

**Passo 4: Validação e Análise do Fluxo de Pacotes (Discussão)**

*   **Fluxo Válido: Requisição do Cliente para o Servidor Web:**
    1.  Cliente (`Internet`) -> IGW -> `Subnet-Web`.
    2.  **NACL da `Subnet-Web` (Inbound):** Permite tráfego na porta 80/443 (se não for o IP bloqueado).
    3.  Instância Web (ENI).
    4.  **`Web-SG` (Inbound):** Permite tráfego na porta 80/443 da internet.
    5.  Servidor Web processa.
    6.  Servidor Web (ENI).
    7.  **`Web-SG` (Outbound):** Permite tráfego de resposta de volta ao cliente (stateful).
    8.  `Subnet-Web` -> IGW -> Cliente.

*   **Fluxo Válido: Requisição da Camada Web para a Camada de Aplicação:**
    1.  Instância Web -> `Subnet-Web`.
    2.  **NACL da `Subnet-Web` (Outbound):** Permite tráfego para a `Subnet-App` na porta 8080.
    3.  `Subnet-Web` -> Roteador da VPC -> `Subnet-App`.
    4.  **NACL da `Subnet-App` (Inbound):** Permite tráfego da `Subnet-Web` na porta 8080.
    5.  Instância App (ENI).
    6.  **`App-SG` (Inbound):** Permite tráfego na porta 8080 do `Web-SG`.
    7.  Servidor App processa.
    8.  Servidor App (ENI).
    9.  **`App-SG` (Outbound):** Permite tráfego de resposta de volta ao `Web-SG` (stateful).
    10. `Subnet-App` -> Roteador da VPC -> `Subnet-Web`.
    11. **NACL da `Subnet-App` (Outbound):** Permite tráfego de resposta para a `Subnet-Web` nas portas efêmeras.
    12. **NACL da `Subnet-Web` (Inbound):** Permite tráfego de resposta da `Subnet-App` nas portas efêmeras.

*   **Fluxo Inválido: Atacante tenta SSH diretamente no Banco de Dados:**
    1.  Atacante (`Internet`) -> IGW -> `Subnet-DB`.
    2.  **NACL da `Subnet-DB` (Inbound):** Não há regra `ALLOW` para a porta 22 de `0.0.0.0/0`. A regra implícita `DENY ALL` é aplicada. O pacote é **descartado imediatamente**.
    3.  O tráfego nunca chega à instância do DB, e o `DB-SG` nunca é avaliado para este tráfego.

Este laboratório demonstra como a combinação estratégica de NACLs para bloqueios amplos e SGs para controle refinado cria uma postura de segurança robusta e em camadas, aderindo ao princípio da Defesa em Profundidade.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Princípio do Menor Privilégio:** Sempre comece com as regras mais restritivas e adicione permissões apenas quando estritamente necessário.
*   **SGs para Controle de Aplicação, NACLs para Perímetro:** Use Security Groups para controlar o acesso a instâncias individuais e aplicações, e NACLs para controle de tráfego em nível de sub-rede, especialmente para blacklisting ou whitelisting de grandes blocos de IP.
*   **Ordem das Regras na NACL:** Lembre-se que as NACLs processam as regras em ordem numérica. Coloque as regras `DENY` mais específicas com números menores para garantir que sejam avaliadas antes das regras `ALLOW` mais amplas.
*   **NACLs Stateless:** Não se esqueça de configurar regras de entrada e saída para o tráfego de resposta nas NACLs. Um erro comum é permitir o tráfego de entrada, mas esquecer de permitir a resposta de saída, ou vice-versa.
*   **Referência de Security Groups:** Sempre que possível, use referências a Security Groups em vez de blocos CIDR para permitir a comunicação entre recursos. Isso torna as regras mais dinâmicas e fáceis de gerenciar.
*   **Documentação:** Documente suas regras de Security Group e NACL, explicando o propósito de cada uma. Isso é crucial para a manutenção e auditoria.
*   **Monitoramento:** Utilize VPC Flow Logs (Módulo 3.1) para monitorar o tráfego que é permitido ou negado por suas NACLs e Security Groups. Isso ajuda a identificar tentativas de acesso não autorizado e a depurar problemas de conectividade.
*   **Firewall de Host:** Considere usar firewalls baseados em host (como `iptables` ou `firewalld` no Linux) como uma camada adicional de defesa, especialmente para servidores críticos.
