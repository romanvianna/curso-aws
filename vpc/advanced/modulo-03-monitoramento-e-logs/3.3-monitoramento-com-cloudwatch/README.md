# Módulo 3.3: Monitoramento com CloudWatch

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Pré-requisitos

*   Conhecimento básico de métricas de sistemas (CPU, memória, rede).
*   Familiaridade com os serviços EC2, ALB e NAT Gateway.
*   Noções básicas de notificações (e-mail, SMS).

## Objetivos

*   Entender o CloudWatch como a plataforma central de observabilidade da AWS, abrangendo métricas, logs e eventos.
*   Analisar as métricas de rede chave para os principais componentes da VPC (EC2, NAT GW, ALB), compreendendo seu significado e impacto.
*   Aprender a criar dashboards customizados para correlação de métricas e visualização da saúde da rede e da aplicação.
*   Configurar alarmes proativos para ser notificado sobre condições anormais antes que elas impactem os usuários.
*   Discutir a importância do monitoramento proativo para a resiliência e performance de aplicações em produção.

---

## 1. Monitoramento Proativo vs. Reativo (Teoria - 45 min)

Em operações de TI, existem duas abordagens para o monitoramento:

*   **Monitoramento Reativo:** Você espera que um problema aconteça (um alerta de "servidor offline", um ticket de cliente, uma reclamação de usuário) e então usa as ferramentas para investigar a causa raiz. Isso leva a tempo de inatividade (downtime) e impacta negativamente a experiência do usuário e a reputação da empresa.
*   **Monitoramento Proativo (Observabilidade):** Você monitora os **sintomas** e os **indicadores de saúde** do seu sistema para prever e identificar problemas **antes** que eles se tornem falhas críticas. Você não espera o paciente ter uma parada cardíaca; você monitora sua pressão arterial e seu pulso. O objetivo é detectar anomalias e agir antes que o problema se manifeste para o usuário final.

O **Amazon CloudWatch** é a ferramenta que permite passar de uma postura reativa para uma proativa, através de seus três componentes principais: **Métricas, Alarmes e Dashboards**.

### 1. CloudWatch Metrics: Os Sinais Vitais do Sistema

Uma **métrica** é uma série de dados ordenada por tempo (time-series data). Pense nela como um "sinal vital" da sua infraestrutura (ex: uso de CPU, tráfego de rede, contagem de erros). A AWS publica automaticamente métricas para a maioria dos seus serviços, sem custo adicional para as métricas básicas.

**Métricas de Rede Chave a Serem Observadas:**

*   **Instâncias EC2:**
    *   `CPUUtilization`: O sintoma mais comum de sobrecarga. Se a CPU estiver em 100% por muito tempo, a instância não conseguirá processar o tráfego de rede de forma eficiente, levando a latência e erros.
    *   `NetworkPacketsIn`/`Out`: Picos ou quedas repentinas no número de pacotes podem indicar um ataque de negação de serviço (DDoS), uma falha na aplicação ou problemas de conectividade.
    *   `CPUCreditBalance` (para tipos T): **Crítico para instâncias burstáveis**. Se o saldo de créditos de CPU de uma instância "burstável" (T2, T3, T4g) se esgotar, sua performance cairá drasticamente (CPU Steal). Este é um problema silencioso que pode derrubar sua aplicação sem que a `CPUUtilization` atinja 100%.

*   **NAT Gateway:**
    *   `ErrorPortAllocation`: **Crítico**. Se esta métrica for maior que zero, significa que o NAT Gateway ficou sem portas de origem disponíveis para criar novas conexões. Suas instâncias privadas não conseguirão mais acessar a internet, impactando atualizações, acesso a APIs externas, etc. Isso acontece sob carga muito alta ou com muitas conexões de curta duração.
    *   `PacketsDropped`: Se o NAT Gateway estiver descartando pacotes, é um sinal de que ele está sobrecarregado ou mal configurado.

*   **Application Load Balancer (ALB):**
    *   `UnHealthyHostCount`: **O indicador de saúde mais importante da sua aplicação**. Se este número for maior que zero, significa que o ALB detectou que uma ou mais das suas instâncias de back-end não estão respondendo corretamente aos health checks. Isso indica um problema na aplicação ou na instância.
    *   `HTTPCode_Target_5XX_Count`: Um aumento no número de erros 5xx (erros do servidor) indica um problema na sua aplicação de back-end (ex: erros de código, problemas de banco de dados).
    *   `TargetConnectionErrorCount`: Indica problemas de rede entre o ALB e suas instâncias de back-end (ex: um Security Group bloqueando o tráfego, problemas de rede na instância).
    *   `RequestCount`: Monitora o volume de requisições, útil para identificar picos de tráfego ou ataques.

### 2. CloudWatch Alarms: O Sistema de Alerta Precoce

Monitorar métricas manualmente não é escalável. Um **Alarme do CloudWatch** automatiza esse processo. Ele observa uma métrica e realiza uma ação se a métrica cruzar um limite que você definir por um determinado período.

*   **Estado do Alarme:** Um alarme tem três estados: `OK` (métrica dentro do limite), `ALARM` (métrica fora do limite), `INSUFFICIENT_DATA` (dados insuficientes para avaliar).
*   **Ações:** Quando um alarme entra no estado `ALARM`, ele pode:
    *   **Notificar:** Enviar uma mensagem para um **tópico do Amazon SNS**. Você pode inscrever e-mails, endpoints de SMS, ou até mesmo webhooks do Slack ou PagerDuty neste tópico para notificar as equipes responsáveis.
    *   **Remediar:** Realizar uma ação de EC2 (parar/reiniciar/recuperar uma instância) ou acionar uma política de Auto Scaling (adicionar mais instâncias).

### 3. CloudWatch Dashboards: O Painel de Controle Central

Um **Dashboard do CloudWatch** é uma página customizável onde você pode montar gráficos de suas métricas mais importantes, de diferentes serviços, em uma única visualização. Isso é essencial para a **correlação de eventos** e para ter uma visão holística da saúde do seu ambiente.

*   **Exemplo:** Se você vir um pico no `HTTPCode_Target_5XX_Count` do seu ALB, pode olhar para o gráfico de `CPUUtilization` das suas instâncias no mesmo dashboard e no mesmo período. Se a CPU também estiver em 100%, você encontrou a causa raiz rapidamente. O dashboard permite que você veja a história completa em um só lugar, facilitando o troubleshooting e a tomada de decisões.

---

## 2. Criação de Dashboards e Alertas (Prática - 75 min)

Neste laboratório, vamos construir um sistema de monitoramento proativo para nossa aplicação, criando um dashboard e um alarme crítico para o nosso ALB. Isso simula um ambiente de produção onde a detecção rápida de problemas é essencial.

### Cenário: Monitoramento de Aplicação Web de Alta Disponibilidade

Uma empresa de SaaS (Software as a Service) hospeda sua aplicação web na AWS, utilizando ALBs para distribuir o tráfego e instâncias EC2 em Auto Scaling Groups. Eles precisam de um sistema de monitoramento robusto para garantir a disponibilidade e performance da aplicação, alertando a equipe de operações sobre qualquer anomalia.

### Roteiro Prático

**Passo 1: Criar um Tópico SNS para Notificações**
1.  Navegue até o **Amazon SNS** > **Topics** > **Create topic**.
2.  **Type:** `Standard`, **Name:** `Critical-App-Alarms`.
3.  Após criar o tópico, vá para a aba **"Subscriptions"** > **"Create subscription"**.
4.  **Protocol:** `Email`, **Endpoint:** Insira seu endereço de e-mail pessoal para receber as notificações.
5.  **Confirme a inscrição** clicando no link que você receberá por e-mail. Sem a confirmação, você não receberá os alertas.

**Passo 2: Criar um Alarme Crítico para a Saúde da Aplicação**
Vamos criar um alarme que dispara imediatamente se qualquer instância de back-end ficar indisponível, indicando um problema grave na aplicação.

1.  Navegue até o **CloudWatch** > **Alarms** > **Create alarm** > **Select metric**.
2.  Vá para **ApplicationELB > Per AppELB, Per TG Metrics**.
3.  Encontre e selecione a métrica `UnHealthyHostCount` para o seu `Lab-ALB` e `Lab-App-TG` (criados no Módulo 1.2).
4.  **Specify metric and conditions:**
    *   **Statistic:** `Maximum` (queremos saber o pico de instâncias não saudáveis no período).
    *   **Period:** `1 Minute` (avalia a cada minuto).
    *   **Conditions:** `Static`, `Greater (>)`, `0` (dispara se houver pelo menos 1 host não saudável).
    *   **Datapoints to alarm:** `1 out of 1` (dispara no primeiro ponto de dados que viola o limite).
5.  **Configure actions:**
    *   **Alarm state trigger:** `In alarm`.
    *   **Send a notification to:** Selecione o tópico `Critical-App-Alarms` que você criou.
6.  **Alarm name:** `ALB_Unhealthy_Hosts_CRITICAL`
7.  Clique em **"Create alarm"**.

**Passo 3: Criar um Dashboard de Saúde da Aplicação**

1.  No CloudWatch, vá para **Dashboards** > **Create dashboard**.
2.  **Dashboard name:** `WebApp-Health-Dashboard`
3.  **Adicionar Widgets:**
    *   **Widget 1 (Status do Alarme):** Adicione um widget do tipo **"Alarm status"** e selecione o alarme `ALB_Unhealthy_Hosts_CRITICAL`. Isso dará uma visão rápida do estado do alarme.
    *   **Widget 2 (Saúde dos Alvos):** Adicione um widget de **Linha** com as métricas `HealthyHostCount` e `UnHealthyHostCount` do seu Target Group. Isso mostra a saúde das instâncias por trás do ALB.
    *   **Widget 3 (Requisições e Erros):** Adicione um widget de **Linha** com as métricas `RequestCount`, `HTTPCode_Target_4XX_Count`, e `HTTPCode_Target_5XX_Count` do seu ALB. Isso ajuda a identificar problemas na aplicação ou picos de tráfego.
    *   **Widget 4 (CPU dos Servidores):** Adicione um widget de **Linha** com a métrica `CPUUtilization` para **todas** as instâncias no seu Target Group. Isso ajuda a correlacionar problemas de aplicação com o uso de recursos.
    *   **Widget 5 (Latência do ALB):** Adicione um widget de **Linha** com a métrica `TargetResponseTime` do seu ALB. Isso indica a latência da aplicação.
4.  Reorganize e salve o dashboard. Explore as opções de visualização e períodos de tempo.

**Passo 4: Testar o Sistema de Alerta (Simular uma Falha)**

1.  Vá para o console do **EC2** e **pare** uma das instâncias de aplicação que está no Target Group do ALB.
2.  Aguarde alguns minutos (o tempo do período do alarme e dos health checks do ALB) e observe o que acontece:
    *   **Dashboard:** O gráfico `UnHealthyHostCount` subirá para 1. O widget de status do alarme ficará vermelho e mostrará `In alarm`.
    *   **Alarme:** O alarme no console do CloudWatch mudará de estado para `In alarm`.
    *   **Notificação:** Você receberá um e-mail do SNS informando que o alarme disparou, com detalhes sobre a métrica e o limite.

3.  **Não se esqueça de iniciar a instância novamente** para restaurar a saúde do sistema. O alarme voltará para o estado `OK`.

Este laboratório mostra como passar de um monitoramento passivo para uma observabilidade proativa, usando as ferramentas do CloudWatch para visualizar a saúde da sua rede e ser alertado sobre problemas antes que eles afetem seus usuários.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Monitore os Sintomas, Não Apenas as Causas:** Em vez de apenas monitorar a CPU, monitore métricas que impactam diretamente o usuário, como latência da aplicação, taxa de erros HTTP e contagem de hosts não saudáveis.
*   **Alarmes Acionáveis:** Crie alarmes que sejam acionáveis. Evite "alarmes de ruído" que disparam com frequência sem indicar um problema real. Ajuste os limites e períodos para minimizar falsos positivos.
*   **Use SNS para Notificações:** O Amazon SNS é o serviço ideal para centralizar notificações de alarmes. Ele pode enviar mensagens para e-mail, SMS, filas SQS, funções Lambda e webhooks.
*   **Dashboards para Correlação:** Crie dashboards que agrupem métricas relacionadas de diferentes serviços. Isso facilita a correlação de eventos e a identificação da causa raiz de problemas.
*   **Retenção de Métricas:** O CloudWatch armazena métricas por 15 meses. Configure a retenção de logs no CloudWatch Logs de acordo com suas necessidades de auditoria e troubleshooting.
*   **Métricas Personalizadas:** Se as métricas padrão da AWS não forem suficientes, você pode publicar suas próprias métricas personalizadas no CloudWatch a partir de suas aplicações ou scripts.
*   **CloudWatch Contributor Insights:** Use o Contributor Insights para identificar os principais contribuidores para o comportamento de uma métrica (ex: qual IP está gerando mais tráfego, qual usuário está fazendo mais chamadas de API).
*   **CloudWatch Anomaly Detection:** Habilite a detecção de anomalias para métricas importantes. O CloudWatch aprenderá o comportamento normal da métrica e alertará sobre desvios, sem a necessidade de definir limites estáticos.
