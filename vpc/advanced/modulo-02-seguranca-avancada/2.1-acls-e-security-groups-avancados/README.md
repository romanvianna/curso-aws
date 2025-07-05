# Módulo 2.1: ACLs e Security Groups Avançados

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Compreender o princípio de segurança de **Defesa em Profundidade (Defense in Depth)**.
- Aplicar este princípio usando Security Groups e Network ACLs como camadas de segurança complementares.
- Analisar o fluxo de pacotes através das camadas de segurança da VPC.
- Implementar uma arquitetura de segurança multicamada para uma aplicação web, validando o isolamento entre as camadas.

---

## 1. O Modelo de Defesa em Profundidade (Teoria - 60 min)

**Defesa em Profundidade** é uma estratégia de segurança da informação que, em vez de depender de uma única barreira, utiliza uma série de mecanismos de segurança em camadas. A intenção é que, se uma camada for contornada por um invasor, a próxima camada possa conter ou, pelo menos, retardar o ataque. É o princípio de não colocar todos os ovos na mesma cesta.

Em uma rede, isso significa ir além do tradicional "firewall de perímetro". Em vez de ter apenas um muro forte ao redor do castelo, colocamos guardas em cada portão, portas trancadas em cada sala e um cofre para os bens mais preciosos. 

Na AWS VPC, as duas principais camadas de firewall de rede que nos permitem implementar a Defesa em Profundidade são as **Network ACLs** e os **Security Groups**.

### O Fluxo de um Pacote e as Camadas de Defesa

Vamos seguir a jornada de um pacote de dados de entrada, vindo da internet para uma instância EC2 em uma sub-rede:

1.  **Internet Gateway (IGW):** O pacote entra na VPC.
2.  **Tabela de Rotas da VPC:** O roteador da VPC direciona o pacote para a sub-rede de destino.
3.  **CAMADA 1: Network ACL (O Muro do Bairro)**
    -   O pacote chega à fronteira da sub-rede. A Network ACL associada a essa sub-rede é a primeira a inspecioná-lo.
    -   A NACL é **stateless** e verifica suas regras em ordem numérica.
    -   Se houver uma regra de `DENY` que corresponda ao pacote, ele é **descartado imediatamente**. Fim da história. Ele nunca chega à instância.
    -   Se houver uma regra de `ALLOW` correspondente, o pacote tem permissão para entrar na sub-rede.
4.  **CAMADA 2: Security Group (A Porta da Casa)**
    -   O pacote agora chegou à interface de rede (ENI) da instância EC2. O Security Group associado a essa ENI o inspeciona.
    -   O SG é **stateful** e avalia todas as suas regras de `ALLOW`.
    -   Se houver uma regra que permita o tráfego (com base na origem, porta e protocolo), o pacote é entregue ao sistema operacional da instância.
    -   Se nenhuma regra de `ALLOW` corresponder, o pacote é **descartado**. Fim da história.
5.  **CAMADA 3: Firewall do Host (O Segurança Dentro de Casa)**
    -   Mesmo que o pacote passe pela NACL e pelo SG, ainda pode haver um firewall rodando no próprio sistema operacional da instância (como `iptables` no Linux ou o Firewall do Windows). Esta é uma terceira camada de defesa que você mesmo gerencia.

### Papéis Estratégicos das Camadas

Como as duas camadas têm características diferentes, elas devem ser usadas para propósitos estratégicos diferentes:

-   **Network ACLs (Stateless, `Allow`/`Deny`, Nível da Sub-rede):**
    -   **Função:** Ferramenta de força bruta, controle de perímetro.
    -   **Estratégia:** Use-as para regras amplas e de alta confiança. Como elas são stateless e podem causar problemas se mal configuradas (ex: esquecer de permitir o tráfego de resposta), use-as com moderação para fins específicos:
        -   **Blacklisting:** Bloquear explicitamente endereços IP maliciosos conhecidos. Uma regra de `DENY` na NACL é a maneira mais eficiente de fazer isso.
        -   **Whitelisting de Perímetro:** Em um ambiente de alta segurança, você pode configurar a NACL para negar tudo por padrão e permitir explicitamente o tráfego apenas de redes confiáveis (ex: o IP da sua empresa).

-   **Security Groups (Stateful, Apenas `Allow`, Nível da Instância):**
    -   **Função:** Ferramenta de precisão, controle de acesso à aplicação.
    -   **Estratégia:** Esta deve ser sua principal ferramenta de firewall no dia a dia. A abordagem é sempre o **Princípio do Menor Privilégio**.
        -   **Microssegmentação:** Crie SGs granulares para cada camada ou serviço da sua aplicação (ex: `web-sg`, `app-sg`, `db-sg`).
        -   **Referências de Grupo:** Use referências de SG como origem para definir as regras de comunicação entre as camadas. Isso é mais seguro e escalável do que usar blocos CIDR.

---

## 2. Implementação de Arquitetura de Segurança Multicamada (Prática - 60 min)

Neste laboratório, vamos aplicar a Defesa em Profundidade, configurando uma NACL e Security Groups para proteger uma aplicação de 3 camadas (Web, App, DB).

### Cenário

-   **VPC com 3 Sub-redes:** `Subnet-Web` (Pública), `Subnet-App` (Privada), `Subnet-DB` (Privada).
-   **Security Groups:** `Web-SG`, `App-SG`, `DB-SG` para microssegmentação.
-   **Network ACL:** Uma NACL customizada para a sub-rede do banco de dados, como uma camada extra de proteção.

### Roteiro Prático

**Passo 1: Configurar os Security Groups (A Guarda Pessoal)**
1.  **`DB-SG`:**
    -   Regra de Entrada: `Allow TCP port 3306` from `Source: App-SG`.
2.  **`App-SG`:**
    -   Regra de Entrada: `Allow TCP port 8080` from `Source: Web-SG`.
3.  **`Web-SG`:**
    -   Regra de Entrada: `Allow TCP ports 80, 443` from `Source: 0.0.0.0/0`.

**Passo 2: Configurar a Network ACL da Camada de Dados (O Muro do Cofre)**
Vamos criar uma NACL extra-restritiva para a sub-rede do banco de dados.
1.  Crie uma nova NACL: `Name: DB-NACL`, na sua `Lab-VPC`.
2.  **Edite as Regras de Entrada (Inbound):**
    -   Lembre-se que uma NACL customizada nega tudo por padrão.
    -   **Regra 100:** `ALLOW TCP port 3306` from `CIDR da Subnet-App`. (Permite a conexão inicial da camada de aplicação).
    -   **Regra 110:** `ALLOW TCP ports 1024-65535` from `CIDR da Subnet-App`. (Permite o tráfego de resposta se o DB precisar iniciar uma conexão com a camada de App, o que é raro, mas é uma boa prática).
3.  **Edite as Regras de Saída (Outbound):**
    -   **Regra 100:** `ALLOW TCP ports 1024-65535` to `CIDR da Subnet-App`. (Esta é a regra **crítica** para o tráfego de resposta da conexão iniciada pela camada de App).
4.  **Associe a `DB-NACL` à `Subnet-DB`:**
    -   Vá para a aba "Subnet associations" da `DB-NACL` e associe-a à sua sub-rede de banco de dados.

**Passo 3: Adicionar uma Regra de Negação Explícita (Blacklisting)**
1.  Vamos supor que o endereço IP `203.0.113.5` é um atacante conhecido.
2.  Vá para a NACL associada à sua **sub-rede pública**.
3.  Adicione uma nova regra de **entrada** com um número baixo:
    -   **Rule Number:** `90`
    -   **Type:** `All Traffic`
    -   **Source:** `203.0.113.5/32`
    -   **Allow/Deny:** **DENY**
4.  Salve a regra. Agora, este IP está bloqueado no perímetro da sua VPC.

**Passo 4: Validação (Discussão)**
-   **Fluxo Válido:** Uma requisição da camada de App para o DB.
    -   O pacote sai da `Subnet-App`.
    -   Ele chega à `Subnet-DB`. A `DB-NACL` o inspeciona. A regra 100 permite o tráfego na porta 3306 do CIDR da App. O pacote entra.
    -   Ele chega à instância do DB. O `DB-SG` o inspeciona. A regra permite tráfego da origem `App-SG`. O pacote é aceito.
    -   A resposta do DB sai da instância.
    -   Ela chega à `DB-NACL` para sair da sub-rede. A regra de saída 100 permite o tráfego de resposta para o CIDR da App. A resposta flui de volta.
-   **Fluxo Inválido:** Um servidor web comprometido tenta escanear a porta 22 (SSH) do banco de dados.
    -   O pacote chega à `Subnet-DB`. A `DB-NACL` o inspeciona. Não há regra para a porta 22. A regra `*` no final nega o pacote. Ele é descartado.
    -   O `DB-SG` nunca chega a ver este tráfego.

Este laboratório demonstra como a combinação estratégica de NACLs para bloqueios amplos e SGs para controle refinado cria uma postura de segurança robusta e em camadas, aderindo ao princípio da Defesa em Profundidade.