# Módulo 3.2: GuardDuty e Security Hub

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Entender o conceito de Detecção de Ameaças Inteligente (Intelligent Threat Detection).
- Aprender como o Amazon GuardDuty usa machine learning e fontes de inteligência de ameaças para detectar atividades maliciosas.
- Aprender como o AWS Security Hub agrega, organiza e prioriza os alertas de segurança de múltiplos serviços da AWS.
- Habilitar e analisar os resultados (findings) do GuardDuty e do Security Hub.

---

## 1. Detecção e Gerenciamento de Ameaças em Escala (Teoria - 60 min)

À medida que um ambiente de nuvem cresce, o volume de logs (CloudTrail, VPC Flow Logs, DNS logs) se torna gigantesco. Analisar manualmente esses logs para encontrar atividades suspeitas é como procurar uma agulha em um palheiro. Precisamos de serviços inteligentes que possam fazer essa análise por nós e nos alertar sobre ameaças reais.

### Amazon GuardDuty: O Detetive Inteligente da sua Conta

O **Amazon GuardDuty** é um serviço de **detecção de ameaças** que monitora continuamente sua conta e cargas de trabalho da AWS em busca de atividades maliciosas ou não autorizadas. Ele não é um firewall; ele não bloqueia nada. Sua função é **detectar e alertar**.

**Como o GuardDuty Funciona?**
O GuardDuty analisa de forma contínua e em tempo real três fontes de dados principais:

1.  **Logs do AWS CloudTrail:** Analisa as chamadas de API para detectar atividades anômalas no plano de controle (ex: uma instância EC2 em São Paulo de repente começando a fazer chamadas de API em uma região na Ásia).
2.  **Logs de Fluxo da VPC (VPC Flow Logs):** Analisa os logs de tráfego de rede para detectar padrões suspeitos (ex: uma instância se comunicando com um endereço IP conhecido por minerar criptomoedas).
3.  **Logs de DNS:** Analisa as consultas de DNS feitas a partir da sua VPC para detectar se suas instâncias estão tentando resolver domínios associados a malware ou servidores de comando e controle (C2).

**A Inteligência do GuardDuty:**
O poder do GuardDuty vem de como ele analisa esses dados:

-   **Inteligência de Ameaças (Threat Intelligence):** A AWS mantém e atualiza continuamente listas de ameaças conhecidas (endereços IP maliciosos, domínios de botnets, etc.) a partir de suas próprias operações e de parceiros de segurança como a CrowdStrike. O GuardDuty compara seus logs com essas listas.
-   **Detecção de Anomalias (Machine Learning):** O GuardDuty estabelece uma linha de base (baseline) do comportamento normal da sua conta. Ele então usa modelos de machine learning para detectar desvios dessa linha de base. Por exemplo, ele aprende que suas instâncias de desenvolvimento normalmente só são acessadas a partir de IPs do Brasil. Se um login SSH bem-sucedido ocorrer a partir de um IP da Europa Oriental, ele gerará um alerta de anomalia.

**Resultados (Findings):**
Quando o GuardDuty detecta um problema, ele gera um **resultado (finding)**, que contém informações detalhadas sobre a ameaça e é classificado por severidade (Alta, Média, Baixa).

### AWS Security Hub: O Painel de Controle Único da Segurança

Uma organização usa múltiplos serviços de segurança da AWS (GuardDuty, Inspector, Macie), além de ferramentas de terceiros. Cada um gera seus próprios alertas em seu próprio formato. Isso leva à "fadiga de alertas".

O **AWS Security Hub** resolve esse problema. Ele é um serviço que fornece uma visão abrangente da sua postura de segurança na AWS e ajuda a verificar seu ambiente em relação aos padrões de segurança e melhores práticas.

**Como o Security Hub Funciona?**
1.  **Agregação:** Ele **coleta, agrega e normaliza** os resultados de múltiplos serviços da AWS, incluindo GuardDuty, Amazon Inspector (verificação de vulnerabilidades), Amazon Macie (descoberta de dados sensíveis), e de dezenas de produtos de parceiros.
2.  **Priorização:** Ele correlaciona e prioriza os resultados, ajudando você a focar nos problemas mais críticos.
3.  **Verificações de Conformidade:** O Security Hub executa automaticamente verificações contínuas em relação a padrões de segurança da indústria, como o **CIS AWS Foundations Benchmark** e o **Payment Card Industry Data Security Standard (PCI DSS)**. Ele gera resultados para configurações incorretas (ex: uma porta SSH aberta para o mundo, um bucket S3 público).
4.  **Ação Automatizada:** Ele se integra com o Amazon EventBridge, permitindo que você acione ações de remediação automáticas. Por exemplo, se o Security Hub detectar um bucket S3 que se tornou público, ele pode acionar uma função Lambda para torná-lo privado novamente.

**Em resumo:** O GuardDuty é o detetive que encontra as pistas. O Security Hub é o quadro de investigação que organiza todas as pistas de todos os detetives em um único local, mostra quais são as mais importantes e ajuda a garantir que você está seguindo os procedimentos corretos.

---

## 2. Configuração e Análise de Resultados (Prática - 60 min)

Neste laboratório, vamos habilitar o GuardDuty e o Security Hub e, em seguida, usar uma instância EC2 de teste para gerar um resultado de segurança e ver como ele flui através dos dois serviços.

### Roteiro Prático

**Passo 1: Habilitar o Amazon GuardDuty**
1.  Navegue até o console do **Amazon GuardDuty**.
2.  Se for a primeira vez, clique em **"Get Started"** e depois em **"Enable GuardDuty"**. 
3.  É simples assim. O GuardDuty começa imediatamente a analisar seus logs em segundo plano. Não há agentes para instalar ou fontes de dados para configurar.
4.  **Gerenciamento Multi-Contas (Opcional):** Se você estiver em uma organização, pode designar uma conta como a conta de administrador do GuardDuty e gerenciar centralmente todos os resultados de todas as contas-membro.

**Passo 2: Habilitar o AWS Security Hub**
1.  Navegue até o console do **AWS Security Hub**.
2.  Clique em **"Go to Security Hub"** e depois em **"Enable Security Hub"**.
3.  Ao habilitar, o Security Hub perguntará quais padrões de conformidade você deseja habilitar (ex: CIS AWS Foundations). Habilite-os.
4.  O Security Hub começará imediatamente a agregar resultados existentes do GuardDuty e a executar suas próprias verificações de conformidade. (Pode levar algumas horas para popular completamente).

**Passo 3: Gerar um Resultado de Segurança (Simulação)**
Vamos simular uma atividade que o GuardDuty foi projetado para detectar.
1.  Lance uma instância EC2 (Amazon Linux 2) em uma sub-rede pública.
2.  Conecte-se a ela via SSH.
3.  A partir da instância, execute uma consulta de DNS para um domínio conhecido por estar associado a mineração de criptomoedas (uma atividade comum de instâncias comprometidas).
    ```bash
    dig pool.minergate.com
    ```

**Passo 4: Analisar os Resultados**
*Pode levar de 5 a 30 minutos para o resultado aparecer.*

1.  **Analisar no GuardDuty:**
    -   Vá para o console do **GuardDuty**.
    -   No painel **"Findings"**, você verá um novo resultado com um tipo como `CryptoCurrency:EC2/BitcoinTool.B!DNS`.
    -   Clique no resultado para ver os detalhes: o ID da instância afetada, o nome de domínio consultado, a hora do evento e as táticas, técnicas e procedimentos (TTPs) do MITRE ATT&CK associados.

2.  **Analisar no Security Hub:**
    -   Vá para o console do **Security Hub** > **Findings**.
    -   Você verá o **mesmo resultado** do GuardDuty, mas agora ele está em um formato padronizado (o AWS Security Finding Format - ASFF) ao lado de outros resultados.
    -   Use os filtros para explorar. Filtre por `Severity: HIGH` para ver os problemas mais críticos.
    -   No menu à esquerda, vá para **"Security standards"** e clique no padrão CIS. Você verá uma pontuação de conformidade e uma lista de controles que falharam (ex: "Ensure no security groups allow ingress from 0.0.0.0/0 to port 22"). Cada controle falho é um resultado que você pode investigar.

**Passo 5: Tomar Ação**
1.  No Security Hub, você pode selecionar um resultado e, no menu **"Actions"**, mudar seu status de fluxo de trabalho para `NOTIFIED` ou `SUPPRESSED`.
2.  Você também pode adicionar notas personalizadas para rastrear sua investigação.

Este laboratório demonstra como o GuardDuty e o Security Hub trabalham juntos para automatizar a detecção de ameaças e centralizar o gerenciamento da postura de segurança, permitindo que as equipes de segurança foquem na investigação e remediação, em vez de na análise manual de logs.
