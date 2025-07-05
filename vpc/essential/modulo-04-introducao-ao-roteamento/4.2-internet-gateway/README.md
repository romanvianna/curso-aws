# Módulo 4.2: Internet Gateway (IGW)

**Tempo de Aula:** 45 minutos de teoria, 45 minutos de prática

## Objetivos

- Entender a função de um gateway de borda em uma rede e como o IGW cumpre esse papel.
- Compreender a mecânica da tradução de endereços de rede (NAT) 1:1 realizada pelo IGW.
- Internalizar os três pré-requisitos para que uma instância tenha conectividade com a internet.
- Validar o impacto da presença (ou ausência) de um IGW na conectividade da rede.

---

## 1. O Gateway para a Internet (Teoria - 45 min)

### O Papel de um Gateway de Borda

Em qualquer rede privada, seja em um escritório ou em uma VPC, existe um ponto de demarcação claro entre a rede interna (confiável) e a rede externa (não confiável, como a internet). O dispositivo que fica nessa fronteira e gerencia o tráfego que a cruza é chamado de **gateway de borda** ou **roteador de borda**.

O **Internet Gateway (IGW)** da AWS é a implementação virtual, gerenciada e altamente escalável de um gateway de borda para a sua VPC.

### As Duas Funções Principais do IGW

O IGW realiza duas tarefas essenciais para permitir a conectividade com a internet:

1.  **Fornecer um Alvo de Roteamento (Target):**
    -   Como vimos, para que o tráfego saia da VPC, precisa haver uma rota na tabela de rotas que aponte para um destino. O IGW atua como esse destino.
    -   A rota `0.0.0.0/0 -> igw-xxxxxxxx` na sua tabela de rotas pública está essencialmente dizendo: "Para qualquer tráfego destinado a um lugar que não seja esta VPC, envie-o para o Internet Gateway". Sem o IGW, não haveria um `target` válido para essa rota.

2.  **Realizar a Tradução de Endereços de Rede (NAT) 1:1:**
    -   As instâncias na sua VPC têm endereços IP privados (ex: `10.0.1.50`). Esses endereços não são válidos na internet pública.
    -   Para que uma instância se comunique na internet, ela precisa de um endereço IP público.
    -   Quando você atribui um IP público (ou um Elastic IP) a uma instância, o IGW mantém um mapeamento entre o IP privado e o IP público.
    -   **Fluxo de Saída:** Quando a instância envia um pacote para a internet, o IGW intercepta o pacote, troca o endereço IP de origem (privado) pelo endereço IP de origem correspondente (público) e o envia.
    -   **Fluxo de Entrada:** Quando uma resposta (ou uma nova conexão) chega ao IP público da instância, o IGW a recebe, troca o endereço de destino (público) pelo endereço de destino correspondente (privado) e a encaminha para a instância dentro da VPC.
    -   Este processo é transparente para a instância. Ela só conhece seu próprio IP privado.

### Os 3 Requisitos para Conectividade com a Internet (Revisão Crítica)

Para que uma instância EC2 em sua VPC possa se comunicar com a internet, **TODOS** os três pré-requisitos a seguir devem ser atendidos. A falta de **qualquer um deles** resultará em falha na conectividade. É uma das listas de verificação mais importantes para o troubleshooting de rede na AWS.

1.  **Anexar um Internet Gateway à VPC:**
    -   A VPC em si deve ter um IGW criado e devidamente **anexado** a ela. Sem a "porta" principal, ninguém entra ou sai.

2.  **Configurar uma Rota Pública:**
    -   A **sub-rede** onde a instância está localizada deve estar associada a uma tabela de rotas que contenha uma rota para a internet (`0.0.0.0/0`) apontando para o IGW. Sem o "mapa" que leva à porta, o tráfego se perde.

3.  **Atribuir um Endereço IP Público à Instância:**
    -   A instância EC2 deve ter um endereço IPv4 público (seja ele dinâmico ou um Elastic IP). Sem um endereço público, o IGW não tem para onde mapear o tráfego de entrada e não sabe qual endereço de origem usar para o tráfego de saída.

### Características do IGW

-   **Gerenciado e Escalável:** Você não gerencia o IGW. A AWS garante sua disponibilidade e escala sua capacidade automaticamente para lidar com sua carga de tráfego. Não há gargalo de largura de banda no IGW.
-   **Relação 1:1 com a VPC:** Uma VPC pode ter apenas um IGW anexado, e um IGW pode ser anexado a apenas uma VPC por vez.
-   **Custo:** Não há cobrança pelo IGW em si. A cobrança é pela **transferência de dados** que passa por ele (Data Transfer Out).

---

## 2. Configuração de IGW (Prática - 45 min)

Neste laboratório, vamos demonstrar o papel crítico do IGW, quebrando e restaurando a conectividade com a internet ao manipulá-lo diretamente.

### Cenário

Temos o `Lab-WebServer` rodando na `Lab-Subnet-Public` da nossa `Lab-VPC`. Atualmente, ele tem acesso à internet. Vamos quebrar essa conectividade desanexando o IGW e depois restaurá-la.

### Roteiro Prático

**Passo 1: Validar a Conectividade Existente**
1.  Conecte-se via SSH ao seu `Lab-WebServer`.
2.  Execute um comando para confirmar o acesso à internet:
    `ping -c 3 8.8.8.8`
3.  **Resultado esperado:** Sucesso. A conectividade está funcionando. Mantenha a sessão SSH aberta.

**Passo 2: Desanexar o Internet Gateway (Remover a Porta)**
1.  Em outra janela, navegue até o console da **VPC** > **Internet Gateways**.
2.  Selecione o `Lab-IGW` que está anexado à sua `Lab-VPC`.
3.  Clique em **Actions > Detach from VPC**.
4.  Confirme a desanexação.
    -   **O que aconteceu?** O estado do `Lab-IGW` mudará de "attached" para "detached". A VPC agora está fisicamente desconectada da internet. A rota `0.0.0.0/0` na `Lab-RT-Public` agora está "quebrada" e inativa (o console a mostrará como "blackholed").

**Passo 3: Testar a Perda de Conectividade**
1.  Volte para a sua sessão SSH com o `Lab-WebServer`.
2.  Tente executar o mesmo comando de ping novamente: `ping -c 3 8.8.8.8`
3.  **Resultado esperado:** Falha. O comando ficará "pendurado" e eventualmente resultará em um timeout (`100% packet loss`).
4.  **Observação Importante:** Sua sessão SSH existente **não caiu**. Por quê? Porque a conexão TCP já estava estabelecida e o firewall stateful (o Security Group) a mantém viva. No entanto, qualquer **nova** conexão de ou para a internet falhará.

**Passo 4: Anexar o Internet Gateway Novamente (Recolocar a Porta)**
1.  Volte para o console da VPC e a seção **"Internet Gateways"**.
2.  Selecione o `Lab-IGW` (que está "detached").
3.  Clique em **Actions > Attach to VPC**.
4.  Selecione sua `Lab-VPC` e clique em **"Attach internet gateway"**.
    -   **O que aconteceu?** O IGW está novamente conectado. A rota `0.0.0.0/0` na `Lab-RT-Public` volta a ser funcional automaticamente.

**Passo 5: Validar a Restauração da Conectividade**
1.  Saia da sua sessão SSH atual (`exit`).
2.  Tente se reconectar via SSH ao `Lab-WebServer`.
    -   **Resultado esperado:** Sucesso. Novas conexões agora são possíveis.
3.  Uma vez conectado, execute o comando de ping novamente.
    -   **Resultado esperado:** Sucesso. A conectividade com a internet foi totalmente restaurada.

Este laboratório demonstra de forma clara e prática que o Internet Gateway é o componente físico (virtualizado) que conecta sua VPC à internet. Sem ele, mesmo que as tabelas de rotas e os IPs públicos estejam configurados, não há caminho para o tráfego fluir.