# Módulo 4.1: Tabela de Rotas Básica

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Entender o conceito fundamental de roteamento IP e a lógica de "longest prefix match".
- Analisar em detalhes o propósito e o comportamento da Tabela de Rotas Principal (Main Route Table) em uma VPC.
- Aprender a criar e associar tabelas de rotas customizadas para implementar a segmentação de rede.
- Realizar a configuração e manipulação de tabelas de rotas para validar o controle do fluxo de tráfego.

---

## 1. Conceitos Fundamentais de Roteamento (Teoria - 60 min)

### Como um Roteador "Pensa"?

O roteamento é o processo central que permite a comunicação entre redes diferentes. Um roteador, seja ele um dispositivo físico ou um serviço virtual como o roteador da VPC da AWS, toma decisões com base em um único princípio: para onde encaminhar o próximo pacote de dados que ele recebe. Para fazer isso, ele consulta sua **tabela de roteamento**.

Uma tabela de roteamento é um conjunto de regras, ou rotas. Cada rota mapeia uma **rede de destino** a um **próximo salto (next hop)**.

**Exemplo de Tabela de Roteamento Simplificada:**

| Destino | Próximo Salto |
| :--- | :--- |
| 10.1.1.0/24 | Interface A |
| 10.1.2.0/24 | Interface B |
| 0.0.0.0/0 | Gateway X |

Quando um pacote chega com um endereço de destino, o roteador segue uma lógica simples, mas poderosa:

### Longest Prefix Match (Correspondência de Prefixo Mais Longo)

O roteador examina o endereço de destino do pacote e o compara com todas as rotas em sua tabela para encontrar a rota **mais específica** que corresponda. "Mais específica" significa a rota com o prefixo de rede mais longo (o maior número após a barra no CIDR).

-   **Exemplo:** Um pacote chega com o destino `10.1.1.50`.
    -   Ele corresponde à rota `10.1.1.0/24` (24 bits correspondentes).
    -   Ele também corresponde à rota `0.0.0.0/0` (0 bits correspondentes).
    -   Como `/24` é mais longo que `/0`, o roteador escolhe a primeira rota e envia o pacote para a Interface A.

-   **Exemplo 2:** Um pacote chega com o destino `8.8.8.8` (um servidor DNS do Google).
    -   Ele não corresponde a `10.1.1.0/24`.
    -   Ele não corresponde a `10.1.2.0/24`.
    -   Ele corresponde à rota `0.0.0.0/0`. Esta é a **rota padrão (default route)**. Ela atua como uma rota "catch-all" para qualquer destino que não tenha uma correspondência mais específica.
    -   O roteador envia o pacote para o Gateway X (provavelmente, o caminho para a internet).

Esta lógica é a base de todo o roteamento na internet e dentro da sua VPC.

### Roteamento na AWS VPC

-   **A Rota `local`:** Toda tabela de rotas na AWS tem uma rota padrão para o bloco CIDR da própria VPC (ex: `10.0.0.0/16`) com o alvo `local`. Esta é a rota mais específica para o tráfego interno. Qualquer tráfego destinado a um IP dentro da VPC corresponderá a esta rota primeiro, garantindo a comunicação interna.

-   **Tabela de Rotas Principal (Main Route Table):**
    -   Quando você cria uma VPC, ela vem com uma Tabela de Rotas Principal. Esta é a tabela de rotas padrão para a sua rede.
    -   **Comportamento Crucial:** Qualquer sub-rede que você criar e **não** associar explicitamente a outra tabela de rotas será **automaticamente associada** à Tabela de Rotas Principal.
    -   **Boa Prática de Segurança:** A prática recomendada é deixar a Tabela de Rotas Principal em seu estado mais seguro (privado), contendo apenas a rota `local`. Em seguida, crie tabelas de rotas customizadas para sub-redes que precisam de roteamento especial (como acesso à internet). Isso cria um comportamento "seguro por padrão", onde novas sub-redes são privadas até que você decida o contrário.

-   **Tabelas de Rotas Customizadas:**
    -   Você cria tabelas de rotas customizadas para definir comportamentos de roteamento diferentes para sub-redes diferentes. É assim que implementamos a segmentação de rede (camadas pública e privada).
    -   Uma sub-rede pode ser associada a **apenas uma** tabela de rotas por vez.
    -   Uma tabela de rotas pode ser associada a múltiplas sub-redes.

---

## 2. Configuração de Route Tables (Prática - 60 min)

Neste laboratório, vamos manipular as tabelas de rotas da nossa `Lab-VPC` para demonstrar visualmente como elas controlam o fluxo de tráfego e definem uma sub-rede como pública ou privada.

### Cenário

Temos a `Lab-VPC` com `Lab-Subnet-Public` e `Lab-Subnet-Private`. Vamos dissecar suas tabelas de rotas e simular uma configuração incorreta para entender as consequências.

### Roteiro Prático

**Passo 1: Revisar a Configuração de Roteamento Existente**
1.  Navegue até o console da **VPC** e vá para **"Route Tables"**.
2.  Filtre as tabelas pela sua `Lab-VPC`. Você deve ver `Lab-RT-Public` e `Lab-RT-Private`.

**Passo 2: Analisar a Tabela de Rotas Privada (Principal)**
1.  Selecione a `Lab-RT-Private` (a que tem "Main: Yes").
2.  **Aba "Routes":** Confirme que ela contém **apenas** a rota `local` (`10.0.0.0/16 -> local`). Esta tabela não sabe como chegar à internet.
3.  **Aba "Subnet associations":** Confirme que a `Lab-Subnet-Private` está associada a esta tabela.

**Passo 3: Analisar a Tabela de Rotas Pública**
1.  Selecione a `Lab-RT-Public`.
2.  **Aba "Routes":** Confirme que ela contém duas rotas:
    -   `10.0.0.0/16 -> local`
    -   `0.0.0.0/0 -> <seu-lab-igw>` (A rota padrão para a internet).
3.  **Aba "Subnet associations":** Confirme que a `Lab-Subnet-Public` está explicitamente associada aqui.

**Passo 4: Exercício de "Quebra": Transformando uma Sub-rede Pública em Privada**
Este exercício demonstra o quão crítico é o roteamento correto.
1.  Selecione a `Lab-RT-Public`.
2.  Vá para **"Subnet associations"** e clique em **"Edit subnet associations"**.
3.  **Desmarque** a `Lab-Subnet-Public` e salve.
    -   **O que aconteceu?** A `Lab-Subnet-Public` perdeu sua associação explícita. Por padrão, toda sub-rede sem uma associação explícita reverte para a **Tabela de Rotas Principal**. Nossa Tabela de Rotas Principal é a `Lab-RT-Private`.
    -   **Consequência:** A `Lab-Subnet-Public` agora está usando uma tabela de rotas que não tem um caminho para a internet. Ela se tornou, efetivamente, uma sub-rede privada, apesar de seu nome.
4.  **Teste (Prático):**
    -   Se você tiver uma instância EC2 (como o `Lab-WebServer`) rodando na `Lab-Subnet-Public`, tente se conectar a ela via SSH a partir do seu computador. A conexão falhará com um timeout.
    -   **Por quê?** O tráfego de entrada da internet chega ao IGW, mas quando a VPC tenta rotear o pacote para a sub-rede, a tabela de rotas associada (`Lab-RT-Private`) não tem uma rota de volta para o IGW. A instância pode receber o pacote, mas sua resposta não sabe como sair da VPC.

**Passo 5: Corrigir a Configuração**
1.  Volte para as associações de sub-rede da `Lab-RT-Public`.
2.  **Reassocie** a `Lab-Subnet-Public` à `Lab-RT-Public`.
3.  **Teste Novamente:** A conexão SSH com o `Lab-WebServer` voltará a funcionar imediatamente.

**Passo 6: Alterar a Tabela de Rotas Principal (Demonstração)**
Este passo mostra como você pode mudar qual tabela é a padrão.
1.  Selecione a `Lab-RT-Public`.
2.  Vá em **Actions > Set main route table**.
    -   **O que aconteceu?** Agora, a `Lab-RT-Public` é a tabela principal. Qualquer nova sub-rede que você criar se tornará **pública por padrão**, pois herdará a rota para o IGW. Isso é geralmente considerado uma má prática de segurança.
3.  **Reverta a Mudança:** Selecione a `Lab-RT-Private` e defina-a de volta como a tabela principal para manter o princípio de "seguro por padrão".

Este laboratório prático reforça que o nome de uma sub-rede é apenas uma etiqueta. Seu comportamento real (público ou privado) é definido unicamente pelas rotas na tabela de rotas à qual ela está associada.