# Módulo 3.2: GuardDuty e Security Hub

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento básico de segurança em nuvem e conceitos de ameaças (malware, intrusão).
*   Familiaridade com os serviços AWS CloudTrail e VPC Flow Logs (Módulo 3.1 do Advanced).
*   Noções sobre o console da AWS e gerenciamento de contas.

## Objetivos

*   Entender o conceito de Detecção de Ameaças Inteligente (Intelligent Threat Detection) e por que é essencial em ambientes de nuvem em escala.
*   Aprender como o Amazon GuardDuty usa machine learning, inteligência de ameaças e análise de logs para detectar atividades maliciosas e anômalas.
*   Compreender o papel do AWS Security Hub como um agregador, organizador e priorizador de alertas de segurança de múltiplos serviços da AWS e parceiros.
*   Habilitar e analisar os resultados (findings) gerados pelo GuardDuty e agregados pelo Security Hub.
*   Discutir as melhores práticas para a detecção e resposta a incidentes de segurança na AWS.

---

## 1. Detecção e Gerenciamento de Ameaças em Escala (Teoria - 60 min)

À medida que um ambiente de nuvem cresce, o volume de logs (CloudTrail, VPC Flow Logs, DNS logs) se torna gigantesco. Analisar manualmente esses logs para encontrar atividades suspeitas é como procurar uma agulha em um palheiro. Precisamos de serviços inteligentes que possam fazer essa análise por nós e nos alertar sobre ameaças reais.

### Amazon GuardDuty: O Detetive Inteligente da sua Conta

O **Amazon GuardDuty** é um serviço de **detecção de ameaças** que monitora continuamente sua conta e cargas de trabalho da AWS em busca de atividades maliciosas ou não autorizadas. Ele não é um firewall; ele não bloqueia nada. Sua função é **detectar e alertar**, fornecendo insights acionáveis para sua equipe de segurança.

**Como o GuardDuty Funciona?**
O GuardDuty analisa de forma contínua e em tempo real três fontes de dados principais:

1.  **Logs do AWS CloudTrail:** Analisa as chamadas de API para detectar atividades anômalas no plano de controle (ex: um usuário fazendo chamadas de API de uma região incomum, tentativas de desabilitar logs de segurança, criação de usuários com privilégios excessivos).
2.  **Logs de Fluxo da VPC (VPC Flow Logs):** Analisa os logs de tráfego de rede para detectar padrões suspeitos (ex: uma instância se comunicando com um endereço IP conhecido por minerar criptomoedas, varredura de portas, comunicação com IPs de botnets).
3.  **Logs de DNS:** Analisa as consultas de DNS feitas a partir da sua VPC para detectar se suas instâncias estão tentando resolver domínios associados a malware, servidores de comando e controle (C2) ou phishing.

**A Inteligência do GuardDuty:**
O poder do GuardDuty vem de como ele analisa esses dados:

*   **Inteligência de Ameaças (Threat Intelligence):** A AWS mantém e atualiza continuamente listas de ameaças conhecidas (endereços IP maliciosos, domínios de botnets, URLs de phishing, etc.) a partir de suas próprias operações e de parceiros de segurança como a CrowdStrike. O GuardDuty compara seus logs com essas listas.
*   **Detecção de Anomalias (Machine Learning):** O GuardDuty estabelece uma linha de base (baseline) do comportamento normal da sua conta e de seus recursos. Ele então usa modelos de machine learning para detectar desvios dessa linha de base. Por exemplo, ele aprende que suas instâncias de desenvolvimento normalmente só são acessadas a partir de IPs do Brasil. Se um login SSH bem-sucedido ocorrer a partir de um IP da Europa Oriental, ele gerará um alerta de anomalia.

**Resultados (Findings):**
Quando o GuardDuty detecta um problema, ele gera um **resultado (finding)**, que contém informações detalhadas sobre a ameaça (tipo de ameaça, recurso afetado, hora do evento, IPs envolvidos) e é classificado por severidade (Alta, Média, Baixa). Esses resultados são enviados para o CloudWatch Events (agora EventBridge) e para o AWS Security Hub.

### AWS Security Hub: O Painel de Controle Único da Segurança

Uma organização usa múltiplos serviços de segurança da AWS (GuardDuty, Inspector, Macie), além de ferramentas de terceiros. Cada um gera seus próprios alertas em seu próprio formato. Isso leva à "fadiga de alertas" e dificulta a gestão da postura de segurança.

O **AWS Security Hub** resolve esse problema. Ele é um serviço que fornece uma visão abrangente da sua postura de segurança na AWS e ajuda a verificar seu ambiente em relação aos padrões de segurança e melhores práticas.

**Como o Security Hub Funciona?**
1.  **Agregação e Normalização:** Ele **coleta, agrega e normaliza** os resultados de múltiplos serviços da AWS (GuardDuty, Amazon Inspector para verificação de vulnerabilidades, Amazon Macie para descoberta de dados sensíveis, AWS Config para conformidade de configuração, AWS Firewall Manager) e de dezenas de produtos de parceiros. Todos os resultados são convertidos para um formato padronizado chamado **AWS Security Finding Format (ASFF)**.
2.  **Priorização:** Ele correlaciona e prioriza os resultados, ajudando você a focar nos problemas mais críticos com base na severidade e no impacto potencial.
3.  **Verificações de Conformidade:** O Security Hub executa automaticamente verificações contínuas em relação a padrões de segurança da indústria, como o **CIS AWS Foundations Benchmark**, o **Payment Card Industry Data Security Standard (PCI DSS)**, e o **AWS Foundational Security Best Practices**. Ele gera resultados para configurações incorretas (ex: uma porta SSH aberta para o mundo, um bucket S3 público).
4.  **Ação Automatizada:** Ele se integra com o Amazon EventBridge, permitindo que você acione ações de remediação automáticas. Por exemplo, se o Security Hub detectar um bucket S3 que se tornou público, ele pode acionar uma função Lambda para torná-lo privado novamente.

**Em resumo:** O GuardDuty é o detetive que encontra as pistas de atividades maliciosas. O Security Hub é o quadro de investigação que organiza todas as pistas de todos os detetives (serviços de segurança) em um único local, mostra quais são as mais importantes e ajuda a garantir que você está seguindo os procedimentos corretos e mantendo uma postura de segurança robusta.

## 2. Configuração e Análise de Resultados (Prática - 60 min)

Neste laboratório, vamos habilitar o GuardDuty e o Security Hub e, em seguida, usar uma instância EC2 de teste para gerar um resultado de segurança e ver como ele flui através dos dois serviços. Isso simula um cenário de detecção de ameaças em tempo real.

### Cenário: Detecção de Atividade Maliciosa e Avaliação de Postura de Segurança

Uma equipe de segurança precisa monitorar continuamente a conta AWS em busca de atividades maliciosas e garantir que as configurações de segurança estejam em conformidade com as melhores práticas. Eles usarão GuardDuty para detecção de ameaças e Security Hub para agregação e avaliação de conformidade.

### Roteiro Prático

**Passo 1: Habilitar o Amazon GuardDuty**
1.  Navegue até o console do **Amazon GuardDuty**.
2.  Se for a primeira vez, clique em **"Get Started"** e depois em **"Enable GuardDuty"**. 
3.  É simples assim. O GuardDuty começa imediatamente a analisar seus logs em segundo plano. Não há agentes para instalar ou fontes de dados para configurar. Ele é um serviço regional, então você deve habilitá-lo em cada região que deseja monitorar.
4.  **Gerenciamento Multi-Contas (Opcional):** Se você estiver em uma organização, pode designar uma conta como a conta de administrador do GuardDuty e gerenciar centralmente todos os resultados de todas as contas-membro.

**Passo 2: Habilitar o AWS Security Hub**
1.  Navegue até o console do **AWS Security Hub**.
2.  Clique em **"Go to Security Hub"** e depois em **"Enable Security Hub"**.
3.  Ao habilitar, o Security Hub perguntará quais padrões de conformidade você deseja habilitar (ex: CIS AWS Foundations Benchmark, AWS Foundational Security Best Practices). Habilite-os. (Pode levar algumas horas para o Security Hub popular completamente com os resultados iniciais).

**Passo 3: Gerar um Resultado de Segurança (Simulação)**
Vamos simular uma atividade que o GuardDuty foi projetado para detectar. Esta atividade gerará um finding de "Cryptocurrency Mining".

1.  Lance uma instância EC2 (`t2.micro`, Amazon Linux 2) em uma sub-rede pública. Associe um Security Group que permita SSH do seu IP local.
2.  Conecte-se a ela via SSH.
3.  A partir da instância, execute uma consulta de DNS para um domínio conhecido por estar associado a mineração de criptomoedas (uma atividade comum de instâncias comprometidas). O GuardDuty monitora logs de DNS para isso.
    ```bash
    dig pool.minergate.com
    ```

**Passo 4: Analisar os Resultados**
*Pode levar de 5 a 30 minutos para o resultado aparecer no GuardDuty e ser propagado para o Security Hub.*

1.  **Analisar no GuardDuty:**
    *   Vá para o console do **GuardDuty**.
    *   No painel **"Findings"**, você verá um novo resultado com um tipo como `CryptoCurrency:EC2/BitcoinTool.B!DNS` ou similar.
    *   Clique no resultado para ver os detalhes: o ID da instância afetada, o nome de domínio consultado, a hora do evento e as táticas, técnicas e procedimentos (TTPs) do MITRE ATT&CK associados.

2.  **Analisar no Security Hub:**
    *   Vá para o console do **Security Hub** > **Findings**.
    *   Você verá o **mesmo resultado** do GuardDuty, mas agora ele está em um formato padronizado (o AWS Security Finding Format - ASFF) ao lado de outros resultados de conformidade e de outros serviços.
    *   Use os filtros para explorar. Filtre por `Severity: HIGH` para ver os problemas mais críticos.
    *   No menu à esquerda, vá para **"Security standards"** e clique no padrão CIS. Você verá uma pontuação de conformidade e uma lista de controles que falharam (ex: "Ensure no security groups allow ingress from 0.0.0.0/0 to port 22"). Cada controle falho é um resultado que você pode investigar e remediar.

**Passo 5: Tomar Ação (Gerenciamento de Findings)**
1.  No Security Hub, você pode selecionar um resultado e, no menu **"Actions"**, mudar seu status de fluxo de trabalho para `NOTIFIED`, `SUPPRESSED` (se for um falso positivo ou aceitável) ou `RESOLVED` (após a remediação).
2.  Você também pode adicionar notas personalizadas para rastrear sua investigação e colaborar com a equipe.

Este laboratório demonstra como o GuardDuty e o Security Hub trabalham juntos para automatizar a detecção de ameaças e centralizar o gerenciamento da postura de segurança, permitindo que as equipes de segurança foquem na investigação e remediação, em vez de na análise manual de logs.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Habilite GuardDuty e Security Hub em Todas as Contas e Regiões:** Para uma cobertura de segurança abrangente, habilite esses serviços em todas as suas contas AWS e em todas as regiões onde você opera. Use o AWS Organizations para gerenciamento centralizado.
*   **Monitore os Findings:** Integre os findings do Security Hub com seus sistemas de gerenciamento de incidentes (SIEM, ITSM) ou crie alarmes no CloudWatch para findings de alta severidade.
*   **Automatize a Resposta:** Use EventBridge (CloudWatch Events) para acionar funções Lambda ou outros serviços em resposta a findings específicos do GuardDuty ou Security Hub, automatizando a remediação de problemas comuns.
*   **Revise os Padrões de Conformidade:** Regularmente revise os padrões de conformidade habilitados no Security Hub e trabalhe para remediar as não conformidades. Isso melhora sua postura de segurança geral.
*   **Entenda os Findings:** Não apenas reaja aos findings, mas entenda o que eles significam e a causa raiz. Use os detalhes fornecidos pelo GuardDuty e Security Hub para aprimorar suas defesas.
*   **Teste a Detecção:** Periodicamente, simule atividades maliciosas (em ambientes de teste controlados) para validar se o GuardDuty e o Security Hub estão detectando e alertando corretamente.
*   **Integre com Outras Ferramentas:** O Security Hub pode receber findings de dezenas de produtos de segurança de parceiros da AWS, consolidando ainda mais sua visão de segurança.