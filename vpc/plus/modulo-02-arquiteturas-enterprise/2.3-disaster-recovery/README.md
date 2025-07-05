# Módulo 2.3: Recuperação de Desastres (Disaster Recovery - DR)

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Entender os conceitos fundamentais de Recuperação de Desastres (DR), incluindo RTO e RPO.
- Analisar as diferentes estratégias de DR para a VPC, desde Backup e Restore até Multi-Região Ativo-Ativo.
- Aprender a usar o AWS Backup para automatizar a proteção de dados da infraestrutura.
- Projetar e discutir a implementação de uma estratégia de DR do tipo Pilot Light.

---

## 1. Estratégias de Resiliência a Desastres (Teoria - 60 min)

**Alta Disponibilidade (High Availability - HA)** e **Recuperação de Desastres (Disaster Recovery - DR)** são conceitos relacionados, mas distintos.

-   **HA:** Lida com falhas de componentes individuais dentro de uma única região (ex: uma instância ou uma Zona de Disponibilidade falha). Nosso uso de múltiplas AZs com ALBs e grupos de Auto Scaling é uma estratégia de HA.
-   **DR:** Lida com falhas em larga escala que afetam uma **região inteira** da AWS. Embora extremamente raros, esses eventos (desastres naturais, falhas de rede em grande escala) podem acontecer. Uma estratégia de DR visa restaurar o serviço em outra região da AWS.

### Métricas Chave de DR: RTO e RPO

A escolha da estratégia de DR é um balanço entre custo e necessidade do negócio, medido por dois objetivos:

1.  **RPO (Recovery Point Objective): Objetivo de Ponto de Recuperação**
    -   **Pergunta:** Quanta perda de dados é aceitável?
    -   **Definição:** O ponto máximo no tempo para o qual os dados podem ser restaurados. Um RPO de 1 hora significa que, no pior caso, você pode perder até 1 hora de dados gerados antes do desastre.

2.  **RTO (Recovery Time Objective): Objetivo de Tempo de Recuperação**
    -   **Pergunta:** Quanto tempo podemos ficar offline?
    -   **Definição:** O tempo máximo que a aplicação pode levar para ser restaurada e voltar a operar após um desastre. Um RTO de 4 horas significa que o negócio exige que o serviço esteja de volta ao ar em menos de 4 horas.

**RTO e RPO baixos (minutos ou segundos) são muito mais caros de implementar do que RTO/RPO altos (horas ou dias).**

### Estratégias de DR na AWS (em ordem crescente de custo/complexidade)

1.  **Backup e Restore (Backup e Restauração):**
    -   **RPO/RTO:** Horas a dias.
    -   **Como Funciona:** Você regularmente faz backup dos seus dados (ex: snapshots de EBS, dumps de banco de dados) e os copia para outra região. Em caso de desastre, você provisiona uma nova infraestrutura do zero na região de DR (usando IaC como Terraform) e restaura os dados a partir dos backups.
    -   **Ferramenta Chave:** **AWS Backup**, um serviço gerenciado que centraliza e automatiza o backup de dados em vários serviços da AWS (EBS, RDS, EFS, etc.) e pode copiar os backups entre regiões.

2.  **Pilot Light (Chama Piloto):**
    -   **RPO/RTO:** Dezenas de minutos a horas.
    -   **Como Funciona:** Uma versão mínima da sua infraestrutura, a "chama piloto", está sempre rodando na região de DR. Isso geralmente inclui a infraestrutura de rede (VPC, sub-redes) e os bancos de dados, que recebem replicação contínua da região primária. Os servidores de aplicação não estão rodando, mas as AMIs (imagens de máquina) estão prontas.
    -   **Em caso de desastre:** Você "acende a chama", iniciando os servidores de aplicação (usando Auto Scaling Groups com capacidade definida para 0, que você aumenta para o tamanho necessário) e apontando o DNS para a região de DR.

3.  **Warm Standby (Espera Morna):**
    -   **RPO/RTO:** Minutos.
    -   **Como Funciona:** Uma versão em escala reduzida, mas totalmente funcional, da sua aplicação está sempre rodando na região de DR. Por exemplo, um único servidor de aplicação em vez de um cluster de dez. Os dados são replicados continuamente.
    -   **Em caso de desastre:** Você simplesmente aumenta a escala da infraestrutura na região de DR para lidar com a carga de produção total e aponta o DNS.

4.  **Multi-Região Ativo-Ativo:**
    -   **RPO/RTO:** Segundos ou zero.
    -   **Como Funciona:** A aplicação está rodando com capacidade total em duas ou more regiões simultaneamente, e o tráfego dos usuários é distribuído entre elas (usando serviços como o **Route 53** com políticas de roteamento de latência ou geolocalização).
    -   **Em caso de desastre:** O Route 53 detecta que uma região não está saudável e automaticamente para de enviar tráfego para ela, redirecionando todos os usuários para as regiões saudáveis restantes. Não há tempo de inatividade (downtime).
    -   **Desafio:** Esta é a estratégia mais complexa e cara, especialmente em relação à replicação e consistência de dados entre as regiões.

---

## 2. Projeto de uma Estratégia de DR (Prática - 60 min)

Neste laboratório, vamos focar nos fundamentos da DR, usando o AWS Backup para proteger nossos dados e depois projetar no papel a implementação de uma estratégia Pilot Light.

### Roteiro Prático

**Parte 1: Configurar o AWS Backup (Backup e Restore)**
1.  Navegue até o console do **AWS Backup**.
2.  **Criar um Cofre de Backup (Backup Vault):**
    -   Vá para **Backup vaults > Create backup vault**.
    -   **Name:** `critical-data-vault`
    -   **KMS encryption key:** Use uma chave gerenciada pela AWS.
    -   Crie o cofre.
3.  **Criar uma Regra de Cópia:**
    -   Selecione o cofre recém-criado.
    -   Na seção **"Copy to region"**, clique em **"Add copy rule"**.
    -   **Destination region:** Escolha uma região diferente da sua atual (sua região de DR).
    -   Deixe as outras opções como padrão.
4.  **Criar um Plano de Backup (Backup Plan):**
    -   Vá para **Backup plans > Create backup plan**.
    -   Selecione **"Start with a template"** e escolha `Daily-35day-retention`.
    -   **Backup plan name:** `EC2-Daily-Plan`
    -   Na regra de backup, role para baixo e encontre a seção **"Copy to region"**. Selecione sua região de DR no menu suspenso. Isso instrui o plano a copiar automaticamente os backups para a outra região.
    -   Crie o plano.
5.  **Atribuir Recursos ao Plano:**
    -   Selecione o `EC2-Daily-Plan` e clique em **"Assign resources"**.
    -   **Resource assignment name:** `EC2-Volumes`
    -   **IAM role:** `Default role`.
    -   **Assign resources:** Selecione **"Include specific resource types"**. Escolha `EBS`.
    -   Você pode então atribuir todos os volumes EBS ou volumes com tags específicas.

**Resultado:** Agora, o AWS Backup criará automaticamente snapshots diários de seus volumes EBS, os reterá por 35 dias e, mais importante, os copiará para sua região de DR, fornecendo a base para uma estratégia de Backup e Restore.

**Parte 2: Projetar uma Estratégia Pilot Light (Discussão)**

Vamos projetar no papel como iríamos além do Backup e Restore para uma estratégia Pilot Light para nossa aplicação web.

-   **Região Primária (N. Virginia):**
    -   VPC, sub-redes, ALB, Auto Scaling Group (ASG) com 2 instâncias, banco de dados RDS.

-   **Região de DR (Ohio):**
    -   **Infraestrutura de Rede (Sempre Ativa):**
        -   Usar o Terraform para implantar uma cópia idêntica da nossa VPC, sub-redes, tabelas de rotas e security groups na região de Ohio.
    -   **Dados (Sempre Ativos):**
        -   Configurar o banco de dados RDS na região primária para ter uma **Read Replica (Réplica de Leitura)** entre regiões em Ohio. A replicação é assíncrona, mas contínua.
    -   **Aplicação (Chama Piloto - Desligada):**
        -   Implantar o mesmo ALB e Auto Scaling Group em Ohio.
        -   Configurar o ASG com a mesma Launch Template, mas com a **capacidade desejada/mínima/máxima definida como 0**. As instâncias não estarão rodando, mas a configuração está pronta.
    -   **DNS:**
        -   Usar o **Route 53** com uma política de roteamento de **Failover**. O registro primário aponta para o ALB em N. Virginia. O registro secundário aponta para o ALB em Ohio. O Route 53 monitora a saúde do endpoint primário.

-   **Processo de Failover (Em caso de desastre em N. Virginia):**
    1.  O health check do Route 53 para o ALB primário falha. O Route 53 automaticamente aponta o DNS para o ALB secundário em Ohio.
    2.  **Ação Manual/Automatizada:** Um administrador (ou um script acionado por um alarme do CloudWatch) vai para o ASG em Ohio e muda a capacidade desejada de 0 para 2 (ou mais).
    3.  O ASG provisiona as instâncias de aplicação.
    4.  **Ação Manual/Automatizada:** A Read Replica do RDS em Ohio é **promovida** para se tornar o banco de dados primário e independente.
    5.  A aplicação em Ohio se conecta ao banco de dados recém-promovido e começa a servir o tráfego.

Este projeto demonstra uma estratégia de DR muito mais rápida (RTO/RPO de minutos), onde a infraestrutura central está pronta e aguardando para ser ativada.
