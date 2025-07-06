# Módulo 2.3: Recuperação de Desastres (Disaster Recovery - DR)

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento dos conceitos de Alta Disponibilidade (HA) e resiliência.
*   Familiaridade com serviços AWS como EC2, EBS, RDS, S3 e CloudWatch.
*   Compreensão de VPCs e roteamento.

## Objetivos

*   Entender os conceitos fundamentais de Recuperação de Desastres (DR), incluindo RTO (Recovery Time Objective) e RPO (Recovery Point Objective).
*   Analisar as diferentes estratégias de DR na AWS: Backup e Restore, Pilot Light, Warm Standby e Multi-Região Ativo-Ativo.
*   Aprender a usar o AWS Backup para automatizar a proteção de dados da infraestrutura e a replicação entre regiões.
*   Projetar e discutir a implementação de uma estratégia de DR do tipo Pilot Light para uma aplicação web, focando nos componentes de rede e dados.
*   Compreender o trade-off entre custo, complexidade e os objetivos de RTO/RPO.

---

## 1. Estratégias de Resiliência a Desastres (Teoria - 60 min)

**Alta Disponibilidade (High Availability - HA)** e **Recuperação de Desastres (Disaster Recovery - DR)** são conceitos relacionados, mas distintos.

*   **HA:** Lida com falhas de componentes individuais dentro de uma única região (ex: uma instância ou uma Zona de Disponibilidade falha). Nosso uso de múltiplas AZs com ALBs e grupos de Auto Scaling é uma estratégia de HA.
*   **DR:** Lida com falhas em larga escala que afetam uma **região inteira** da AWS. Embora extremamente raros, esses eventos (desastres naturais, falhas de rede em grande escala) podem acontecer. Uma estratégia de DR visa restaurar o serviço em outra região da AWS.

### Métricas Chave de DR: RTO e RPO

A escolha da estratégia de DR é um balanço entre custo e necessidade do negócio, medido por dois objetivos:

1.  **RPO (Recovery Point Objective): Objetivo de Ponto de Recuperação**
    *   **Pergunta:** Quanta perda de dados é aceitável?
    *   **Definição:** O ponto máximo no tempo para o qual os dados podem ser restaurados. Um RPO de 1 hora significa que, no pior caso, você pode perder até 1 hora de dados gerados antes do desastre. RPOs mais baixos (minutos, segundos) exigem replicação de dados mais frequente ou contínua.

2.  **RTO (Recovery Time Objective): Objetivo de Tempo de Recuperação**
    *   **Pergunta:** Quanto tempo podemos ficar offline?
    *   **Definição:** O tempo máximo que a aplicação pode levar para ser restaurada e voltar a operar após um desastre. Um RTO de 4 horas significa que o negócio exige que o serviço esteja de volta ao ar em menos de 4 horas. RTOs mais baixos (minutos, segundos) exigem infraestrutura pré-provisionada na região de DR.

**RTO e RPO baixos (minutos ou segundos) são muito mais caros e complexos de implementar do que RTO/RPO altos (horas ou dias).** A decisão deve ser baseada nos requisitos de negócio e no custo-benefício.

### Estratégias de DR na AWS (em ordem crescente de custo/complexidade e decrescente de RTO/RPO)

1.  **Backup e Restore (Backup e Restauração):**
    *   **RPO/RTO:** Horas a dias.
    *   **Como Funciona:** Você regularmente faz backup dos seus dados (ex: snapshots de EBS, dumps de banco de dados) e os copia para outra região. Em caso de desastre, você provisiona uma nova infraestrutura do zero na região de DR (usando IaC como Terraform) e restaura os dados a partir dos backups.
    *   **Ferramenta Chave:** **AWS Backup**, um serviço gerenciado que centraliza e automatiza o backup de dados em vários serviços da AWS (EBS, RDS, EFS, DynamoDB, etc.) e pode copiar os backups entre regiões.
    *   **Custo:** Mais baixo, pois a infraestrutura na região de DR só é provisionada em caso de desastre.

2.  **Pilot Light (Chama Piloto):**
    *   **RPO/RTO:** Dezenas de minutos a horas.
    *   **Como Funciona:** Uma versão mínima da sua infraestrutura, a "chama piloto", está sempre rodando na região de DR. Isso geralmente inclui a infraestrutura de rede (VPC, sub-redes), bancos de dados (com replicação contínua da região primária) e talvez alguns serviços essenciais. Os servidores de aplicação não estão rodando, mas as AMIs (imagens de máquina) estão prontas e os Auto Scaling Groups configurados com capacidade zero.
    *   **Em caso de desastre:** Você "acende a chama", iniciando os servidores de aplicação (aumentando a capacidade do ASG) e apontando o DNS para a região de DR. Os dados já estão lá ou sendo replicados.
    *   **Custo:** Moderado, pois há uma infraestrutura mínima sempre ativa.

3.  **Warm Standby (Espera Morna):**
    *   **RPO/RTO:** Minutos.
    *   **Como Funciona:** Uma versão em escala reduzida, mas totalmente funcional, da sua aplicação está sempre rodando na região de DR. Por exemplo, um único servidor de aplicação em vez de um cluster de dez. Os dados são replicados continuamente.
    *   **Em caso de desastre:** Você simplesmente aumenta a escala da infraestrutura na região de DR para lidar com a carga de produção total e aponta o DNS. O tempo de recuperação é menor porque a aplicação já está parcialmente ativa.
    *   **Custo:** Mais alto que Pilot Light, pois mais recursos estão sempre ativos.

4.  **Multi-Região Ativo-Ativo (Multi-Region Active-Active):**
    *   **RPO/RTO:** Segundos ou zero.
    *   **Como Funciona:** A aplicação está rodando com capacidade total em duas ou mais regiões simultaneamente, e o tráfego dos usuários é distribuído entre elas (usando serviços como o **Route 53** com políticas de roteamento de latência ou geolocalização, ou AWS Global Accelerator).
    *   **Em caso de desastre:** O Route 53/Global Accelerator detecta que uma região não está saudável e automaticamente para de enviar tráfego para ela, redirecionando todos os usuários para as regiões saudáveis restantes. Não há tempo de inatividade (downtime) percebido pelo usuário.
    *   **Desafio:** Esta é a estratégia mais complexa e cara, especialmente em relação à replicação e consistência de dados entre as regiões, e exige um design de aplicação que suporte a operação multi-região.
    *   **Custo:** Mais alto, pois você está pagando por infraestrutura duplicada em tempo integral.

## 2. Projeto de uma Estratégia de DR (Prática - 60 min)

Neste laboratório, vamos focar nos fundamentos da DR, usando o AWS Backup para proteger nossos dados e depois projetar no papel a implementação de uma estratégia Pilot Light para uma aplicação web.

### Cenário: Protegendo uma Aplicação de E-commerce Crítica

Uma empresa de e-commerce possui uma aplicação web crítica que precisa de uma estratégia de Recuperação de Desastres robusta. Eles definiram um RPO de algumas horas e um RTO de algumas horas. A região primária é N. Virginia (`us-east-1`) e a região de DR é Ohio (`us-east-2`).

### Roteiro Prático

**Parte 1: Configurar o AWS Backup (Backup e Restore)**

Vamos configurar o AWS Backup para automatizar o backup de volumes EBS e copiá-los para uma região de DR. Isso serve como a base para qualquer estratégia de DR.

1.  Navegue até o console do **AWS Backup**.
2.  **Criar um Cofre de Backup (Backup Vault):**
    *   Vá para **Backup vaults > Create backup vault**.
    *   **Name:** `critical-data-vault`
    *   **KMS encryption key:** Use uma chave gerenciada pela AWS (`aws/backup`).
    *   Crie o cofre.
3.  **Criar um Plano de Backup (Backup Plan):**
    *   Vá para **Backup plans > Create backup plan**.
    *   Selecione **"Build a new plan"**.
    *   **Backup plan name:** `EC2-Daily-Plan`
    *   **Backup rules:**
        *   **Backup rule name:** `Daily-EBS-Backup`
        *   **Backup vault:** `critical-data-vault`
        *   **Backup frequency:** `Daily`
        *   **Backup window:** `Default`
        *   **Lifecycle:** `Retain for 35 days`
        *   **Copy to region:** Selecione sua região de DR (ex: `US East (Ohio) - us-east-2`). Isso instrui o plano a copiar automaticamente os backups para a outra região.
    *   Crie o plano.
4.  **Atribuir Recursos ao Plano:**
    *   Selecione o `EC2-Daily-Plan` e clique em **"Assign resources"**.
    *   **Resource assignment name:** `EC2-Volumes`
    *   **IAM role:** `Default role` (AWS Backup criará uma role com as permissões necessárias).
    *   **Assign resources:** Selecione **"Include specific resource types"**. Escolha `EBS`.
    *   Você pode então atribuir todos os volumes EBS ou volumes com tags específicas (ex: `Environment: Production`).
    *   Clique em Assign resources.

**Resultado:** Agora, o AWS Backup criará automaticamente snapshots diários de seus volumes EBS, os reterá por 35 dias e, mais importante, os copiará para sua região de DR, fornecendo a base para uma estratégia de Backup e Restore.

**Parte 2: Projetar uma Estratégia Pilot Light (Discussão e Desenho)**

Vamos projetar no papel (ou em um editor de texto/ferramenta de diagramação) como iríamos além do Backup e Restore para uma estratégia Pilot Light para nossa aplicação web de e-commerce.

*   **Região Primária (N. Virginia - `us-east-1`):**
    *   **Infraestrutura:** VPC, sub-redes públicas e privadas, Internet Gateway, NAT Gateway, Application Load Balancer (ALB), Auto Scaling Group (ASG) com 2 instâncias EC2 rodando a aplicação web, banco de dados RDS (MySQL/PostgreSQL).

*   **Região de DR (Ohio - `us-east-2`):**
    *   **Infraestrutura de Rede (Sempre Ativa - Provisionada via IaC):**
        *   Uma cópia idêntica da nossa VPC, sub-redes (públicas e privadas), Internet Gateway, NAT Gateway e Security Groups na região de Ohio. Isso garante que a rede esteja pronta para receber o tráfego.
    *   **Dados (Sempre Ativos - Replicados Continuamente):**
        *   Configurar o banco de dados RDS na região primária para ter uma **Read Replica (Réplica de Leitura)** entre regiões em Ohio. A replicação é assíncrona, mas contínua, minimizando o RPO para os dados.
    *   **Aplicação (Chama Piloto - Desligada):**
        *   Implantar o mesmo ALB e Auto Scaling Group em Ohio.
        *   Configurar o ASG com a mesma Launch Template, mas com a **capacidade desejada/mínima/máxima definida como 0**. As instâncias não estarão rodando, mas a configuração está pronta para ser escalada rapidamente.
    *   **DNS (Roteamento de Failover):**
        *   Usar o **Amazon Route 53** com uma política de roteamento de **Failover**. O registro primário aponta para o ALB em N. Virginia. O registro secundário aponta para o ALB em Ohio. O Route 53 monitora a saúde do endpoint primário usando health checks.

*   **Processo de Failover (Em caso de desastre em N. Virginia):**
    1.  O health check do Route 53 para o ALB primário falha. O Route 53 automaticamente aponta o DNS para o ALB secundário em Ohio.
    2.  **Ação Manual/Automatizada:** Um administrador (ou um script acionado por um alarme do CloudWatch) vai para o ASG em Ohio e muda a capacidade desejada de 0 para o número necessário de instâncias (ex: 2).
    3.  O ASG provisiona as instâncias de aplicação em Ohio.
    4.  **Ação Manual/Automatizada:** A Read Replica do RDS em Ohio é **promovida** para se tornar o banco de dados primário e independente. (Este é um passo crítico que pode levar alguns minutos e pode resultar em alguma perda de dados, dependendo do RPO).
    5.  A aplicação em Ohio se conecta ao banco de dados recém-promovido e começa a servir o tráfego.

Este projeto demonstra uma estratégia de DR muito mais rápida (RTO/RPO de minutos a poucas horas) do que um simples Backup e Restore, onde a infraestrutura central está pronta e aguardando para ser ativada.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Defina RTO e RPO:** Antes de escolher uma estratégia de DR, entenda os requisitos de RTO e RPO do seu negócio. Isso guiará suas decisões de arquitetura e investimento.
*   **Teste Regularmente:** Uma estratégia de DR só é eficaz se for testada regularmente. Realize "simulações de desastre" para validar seus planos de failover e failback.
*   **Automação:** Automatize o máximo possível do seu plano de DR usando Infraestrutura como Código (IaC) e scripts. Isso reduz o erro humano e acelera o tempo de recuperação.
*   **Dados são Críticos:** A replicação de dados é o componente mais desafiador da DR. Certifique-se de que seus dados estão sendo replicados de forma consistente e que você pode restaurá-los para o RPO desejado.
*   **DNS é Chave:** O DNS (especialmente o Route 53 com roteamento de failover) é fundamental para direcionar o tráfego para a região de DR em caso de desastre.
*   **Comunicação:** Tenha um plano de comunicação claro para notificar as partes interessadas internas e externas durante um evento de desastre.
*   **Custo-Benefício:** Avalie o custo de cada estratégia de DR em relação ao impacto financeiro e operacional de um desastre. Não super-provisione a DR se o negócio não exigir.
*   **Documentação:** Mantenha sua estratégia de DR bem documentada, incluindo os passos de failover e failback, responsabilidades e contatos.