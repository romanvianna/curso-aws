# Módulo 4.1: Otimização de Performance (Performance Tuning)

**Tempo de Aula:** 90 minutos de teoria, 90 minutos de prática

## Objetivos

- Entender os fatores que impactam a performance de rede na nuvem, como latência e throughput.
- Aprender sobre os recursos de rede aprimorada da AWS: Jumbo Frames e Elastic Network Adapter (ENA).
- Analisar o conceito de Grupos de Posicionamento (Placement Groups) para otimizar a topologia de rede.
- Realizar testes de performance de rede e observar o impacto da otimização.

---

## 1. Física da Rede na Nuvem (Teoria - 90 min)

Embora a nuvem seja definida por software, ela ainda é limitada pelas leis da física. A performance da sua rede na VPC depende de três fatores principais:

1.  **Latência:** O tempo que um pacote leva para viajar de um ponto a outro (medido em milissegundos). É largamente determinada pela **distância física** e pela velocidade da luz. Para minimizar a latência, você deve colocar seus recursos o mais próximo possível dos seus usuários (escolhendo a região da AWS correta) e o mais próximo possível uns dos outros dentro da AWS.

2.  **Throughput (Largura de Banda):** A quantidade de dados que pode ser transferida em um determinado período (medida em Gbps - Gigabits por segundo). Na AWS, o throughput de uma instância EC2 é geralmente determinado pelo seu **tipo e tamanho**. Instâncias maiores têm acesso a mais largura de banda de rede.

3.  **Jitter e Perda de Pacotes:** A variação na latência e a porcentagem de pacotes que se perdem no caminho. Em uma rede bem gerenciada como a da AWS, esses valores são extremamente baixos, mas podem ser impactados por congestionamento ou problemas de hardware.

### Otimizações de Rede no Nível da Instância

A AWS oferece vários recursos para maximizar a performance de rede no nível da instância EC2:

-   **Rede Aprimorada (Enhanced Networking):**
    -   **Conceito:** Uma tecnologia que usa virtualização de I/O de raiz única (SR-IOV) para fornecer maior performance (pacotes por segundo), menor latência e menor jitter. Em vez de o hipervisor emular uma placa de rede, o SR-IOV permite que a instância tenha acesso mais direto ao hardware de rede subjacente.
    -   **Implementação:** A Rede Aprimorada é habilitada através do **Elastic Network Adapter (ENA)**. A maioria dos tipos de instância modernos (famílias M5, C5, T3, etc.) usa e requer o ENA. Para usá-la, você precisa garantir que sua AMI tenha o driver do ENA instalado.

-   **Jumbo Frames:**
    -   **Conceito:** O tamanho padrão de um pacote Ethernet (a Unidade Máxima de Transmissão, ou MTU) é de 1500 bytes. **Jumbo frames** são pacotes Ethernet com um payload de mais de 1500 bytes, tipicamente até 9001 bytes (MTU de 9001).
    -   **Por que usar?** Cada pacote tem uma sobrecarga (overhead) de cabeçalhos. Ao enviar mais dados em um único pacote, você reduz a sobrecarga relativa e o número de pacotes que precisam ser processados. Isso pode aumentar o throughput máximo alcançável e reduzir o uso de CPU para tarefas de rede intensivas.
    -   **Quando usar?** Jumbo frames são mais benéficos para o tráfego **dentro da sua VPC** (ex: entre um cluster de computação de alta performance ou entre servidores de aplicação e um grande cache de dados). O tráfego que sai para a internet será fragmentado para o MTU padrão de 1500 bytes.
    -   **Requisitos:** Todos os dispositivos no caminho da comunicação (as instâncias, os switches virtuais) devem suportar o mesmo tamanho de MTU.

### Otimizações de Rede no Nível da Topologia

-   **Grupos de Posicionamento (Placement Groups):**
    -   **Conceito:** Um grupo de posicionamento é uma construção lógica que influencia a **localização física** das suas instâncias EC2 nos data centers da AWS. Isso permite que você otimize a topologia da sua rede para diferentes tipos de carga de trabalho.
    -   **Tipos:**
        1.  **Cluster:** Agrupa as instâncias o mais próximo possível umas das outras **dentro de uma única Zona de Disponibilidade**. O objetivo é minimizar a latência de rede entre as instâncias. Ideal para aplicações de Computação de Alta Performance (HPC) que precisam de comunicação de baixa latência e alto throughput (ex: MPI, processamento paralelo).
        2.  **Partition (Partição):** Distribui as instâncias em partições lógicas, onde cada partição tem seu próprio rack com sua própria rede e fonte de energia. Garante que a falha de um único rack não afete instâncias em outras partições. Ideal para sistemas distribuídos e de larga escala que precisam reduzir a probabilidade de falhas de hardware correlacionadas (ex: HDFS, Cassandra, Kafka).
        3.  **Spread (Espalhamento):** Coloca um pequeno número de instâncias em hardware distinto para garantir que elas não compartilhem os mesmos racks. Ideal para aplicações críticas onde a falha de uma única instância não pode, de forma alguma, impactar as outras (ex: um cluster de banco de dados com um nó primário e um secundário).

---

## 2. Análise de Performance de Rede (Prática - 90 min)

Neste laboratório, vamos lançar instâncias em um Placement Group do tipo Cluster e usar a ferramenta `iperf3` para medir a performance da rede entre elas, observando o impacto da topologia.

### Cenário

-   Vamos criar um Placement Group do tipo Cluster.
-   Lançaremos duas instâncias dentro deste grupo.
-   Usaremos `iperf3` para executar um teste de benchmark de throughput entre as instâncias.

### Roteiro Prático

**Passo 1: Criar o Placement Group**
1.  Navegue até o console do **EC2 > Placement Groups > Create placement group**.
2.  **Name:** `HPC-Cluster-PG`
3.  **Placement strategy:** `Cluster`
4.  Clique em **"Create group"**.

**Passo 2: Lançar as Instâncias no Placement Group**
1.  Vá para **Instances > Launch instances**.
2.  **Lançar a Instância 1 (Servidor iperf):**
    -   **Name:** `Net-Perf-Server`
    -   **AMI/Tipo:** Amazon Linux 2. Escolha um tipo de instância com boa performance de rede (ex: `c5n.large`).
    -   **Network Settings:** Lance na sua VPC de laboratório.
    -   **Advanced details:** Role para baixo até a seção **"Placement group"** e selecione o `HPC-Cluster-PG` que você criou.
    -   Crie um novo Security Group (`Perf-Test-SG`) que permita todo o tráfego de si mesmo (adicione uma regra de entrada `All traffic` com a origem sendo o próprio `Perf-Test-SG`) e SSH do seu IP.
    -   Lance a instância.
3.  **Lançar a Instância 2 (Cliente iperf):**
    -   Lance uma segunda instância idêntica chamada `Net-Perf-Client`.
    -   Certifique-se de lançá-la no **mesmo Placement Group** (`HPC-Cluster-PG`) e usando o mesmo Security Group (`Perf-Test-SG`).

**Passo 3: Configurar as Instâncias e Executar o Teste**
1.  Conecte-se via SSH a ambas as instâncias.
2.  Em ambas as instâncias, instale a ferramenta de benchmark `iperf3`:
    `sudo yum install iperf3 -y`
3.  **Na instância `Net-Perf-Server`:**
    -   Inicie o `iperf3` em modo de servidor:
        `iperf3 -s`
    -   Ele começará a escutar por conexões na porta padrão 5201.
4.  **Na instância `Net-Perf-Client`:**
    -   Pegue o **IP privado** da instância `Net-Perf-Server`.
    -   Inicie o `iperf3` em modo de cliente, apontando para o servidor:
        `iperf3 -c IP_PRIVADO_DO_SERVER`

**Passo 4: Analisar os Resultados**
1.  O cliente executará um teste de 10 segundos e imprimirá os resultados. A saída mostrará o throughput (largura de banda) alcançado entre as duas instâncias.
    ```
    [ ID] Interval           Transfer     Bitrate         Retr
    [  5]   0.00-10.00  sec  11.0 GBytes  9.45 Gbits/sec    0             sender
    [  5]   0.00-10.04  sec  11.0 GBytes  9.41 Gbits/sec                  receiver
    ```
2.  **Análise:** Devido ao fato de as instâncias estarem em um Placement Group do tipo Cluster, a latência entre elas é extremamente baixa, permitindo que elas saturem sua capacidade de rede e alcancem um throughput muito alto (próximo ao limite do tipo de instância).

**Passo 5: (Opcional) Teste com Jumbo Frames**
1.  Para testar o impacto dos Jumbo Frames, você precisaria:
    -   Verificar se o tipo de instância suporta Jumbo Frames.
    -   Configurar a MTU da interface de rede em ambas as instâncias para 9001:
        `sudo ip link set dev eth0 mtu 9001`
    -   Executar o teste `iperf3` novamente, mas desta vez especificando o tamanho do buffer para corresponder à MTU: `iperf3 -c IP_PRIVADO_DO_SERVER -M 9000`.
    -   Compare os resultados. Em redes de alta velocidade, você pode ver um pequeno aumento no throughput e uma diminuição no uso da CPU.

Este laboratório demonstra como as decisões de topologia física, mesmo em um ambiente virtual, têm um impacto direto na performance da rede e como as ferramentas da AWS, como os Placement Groups, permitem otimizar essa topologia para cargas de trabalho exigentes.
