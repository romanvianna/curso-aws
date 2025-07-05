# Módulo 2.2: Criando as Instâncias EC2 na VPC

**Tempo de Aula:** 30 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento dos conceitos de VPC, sub-redes (públicas e privadas) e Security Groups.
*   Familiaridade com o console da AWS e o serviço EC2.
*   Noções básicas de endereçamento IP (privado e público).

## Objetivos

*   Compreender como as instâncias EC2 se integram à rede da VPC.
*   Entender a importância da seleção da sub-rede para o posicionamento de rede e a segurança da instância.
*   Diferenciar entre IPs públicos dinâmicos e Elastic IPs (EIPs) e seus casos de uso.
*   Lançar instâncias EC2 em sub-redes públicas e privadas, configurando corretamente a atribuição de IP público.
*   Validar a conectividade de instâncias em diferentes tipos de sub-redes.

---

## 1. Conceitos Fundamentais: A Instância como um Inquilino da Rede (Teoria - 30 min)

Uma instância EC2, em sua essência, é um servidor virtual. No entanto, ela não existe em um vácuo. Ela é um "inquilino" que reside em uma "vizinhança" (uma sub-rede) dentro de uma "cidade" (uma VPC). As propriedades e as regras dessa vizinhança ditam fundamentalmente o que a instância pode fazer e quem pode falar com ela.

O ato de lançar uma instância EC2 é um ato de **posicionamento de rede**. As decisões tomadas durante o lançamento determinam o contexto de rede da instância:

1.  **Seleção da VPC:** Define a "cidade" ou o limite de rede privado geral da instância. Todos os recursos dentro da mesma VPC podem se comunicar usando IPs privados, a menos que restrições de Security Group ou Network ACLs sejam aplicadas.
2.  **Seleção da Sub-rede:** Esta é a decisão mais crítica. A sub-rede confere três propriedades à instância:
    *   **Localização Física (Zona de Disponibilidade):** A sub-rede está vinculada a uma única AZ, o que determina em qual data center físico a instância será executada. Esta é a base da resiliência e alta disponibilidade.
    *   **Endereço IP Privado:** A instância recebe um endereço IP do bloco CIDR da sub-rede. Este é seu endereço permanente e imutável (enquanto a instância existir) para comunicação interna na VPC. Este IP é usado para comunicação entre instâncias na mesma VPC ou em VPCs conectadas (via Peering, Transit Gateway, etc.).
    *   **Roteabilidade Externa:** O comportamento de acesso à internet da instância é **herdado** da tabela de rotas associada à sub-rede. Se a tabela de rotas tem um caminho para um Internet Gateway, a instância tem o *potencial* de ser pública. Se não, ela é privada.

### A Mecânica do IP Público

Um endereço IP público na AWS não é configurado *na* instância. A instância em si só conhece seu IP privado. O IP público é uma propriedade gerenciada pela AWS no nível do gateway (Internet Gateway ou NAT Gateway).

*   **Mapeamento 1:1 no IGW:** O Internet Gateway mantém uma tabela de mapeamento NAT 1:1. Quando você atribui um IP público a uma instância, o IGW cria uma entrada que mapeia `IP Público <-> IP Privado`. Todo o tráfego de entrada e saída para esse IP público é traduzido para o IP privado da instância.
*   **Tipos de IP Público:**
    1.  **IP Público Dinâmico:** Conveniente, mas efêmero. O endereço é liberado e um novo é atribuído se a instância for parada e iniciada. Isso o torna inadequado para servidores que precisam de um ponto de extremidade estável (como um servidor web com um registro DNS apontando para ele).
    2.  **Elastic IP (EIP):** Um IP público estático que você aloca para sua conta. Você tem controle total sobre seu ciclo de vida e pode reassociá-lo a diferentes instâncias. É a solução para pontos de extremidade estáveis e é recomendado para servidores de produção que precisam de um IP público fixo.

## 2. Arquitetura e Casos de Uso: Posicionamento de Instâncias em Cenários Reais

### Cenário Simples: Lançamento em Sub-rede Pública (Servidor Web Front-end)

*   **Descrição:** Uma equipe de marketing precisa de um servidor web simples para uma campanha de curta duração. O servidor precisa ser acessível publicamente para os usuários da internet.
*   **Implementação:** A instância EC2 é lançada na **sub-rede pública** da VPC. Durante o lançamento, a opção **"Auto-assign public IP"** é definida como **"Enable"**. Um Security Group (`web-sg`) é anexado para permitir tráfego HTTP/HTTPS e SSH do IP do administrador.
*   **Justificativa:** Este é o caso de uso padrão para recursos que devem servir tráfego diretamente da internet. A combinação da sub-rede pública (que fornece a rota para o IGW) e o IP público (que fornece o mapeamento NAT no IGW) torna a instância acessível. É rápido de configurar e ideal para protótipos ou aplicações de baixo risco.

### Cenário Corporativo Robusto: Lançamento em Sub-rede Privada e o Padrão de Bastion Host (Servidor de Aplicação Back-end)

*   **Descrição:** Uma empresa de saúde precisa implantar um servidor de aplicação que processa registros médicos eletrônicos (EHR). A conformidade com a HIPAA exige que este servidor seja completamente isolado da internet e que o acesso administrativo seja rigorosamente controlado.
*   **Implementação:**
    1.  A instância `ehr-app-server` é lançada na **sub-rede privada** da VPC.
    2.  Durante o lançamento, a opção **"Auto-assign public IP"** é explicitamente definida como **"Disable"**. A instância não terá nenhum IP público, garantindo seu isolamento da internet.
    3.  O Security Group `ehr-app-sg` é anexado, permitindo tráfego apenas do load balancer da aplicação (que está na sub-rede pública) e do bastion host.
    4.  **O Problema do Acesso Administrativo:** Como os administradores acessam este servidor para manutenção, patches ou troubleshooting? Eles não podem se conectar diretamente, pois a instância não tem IP público. A solução é o padrão de **Bastion Host (ou Jump Server)**. Um Bastion Host é uma instância pequena e endurecida, lançada na sub-rede pública, cuja única finalidade é atuar como um ponto de "pulo" seguro. Os administradores se conectam via SSH ao Bastion Host (que tem seu próprio SG altamente restritivo), e a partir do Bastion, eles se conectam via SSH ao IP privado do `ehr-app-server`.
*   **Justificativa:** Este padrão garante que a superfície de ataque do servidor de aplicação seja minimizada. Ele não tem presença direta na internet. Todo o acesso administrativo é afunilado e controlado através de um único ponto de entrada seguro e auditável, atendendo aos requisitos de conformidade e segurança. Este é um padrão fundamental para ambientes de produção.

## 3. Guia Prático (Laboratório - 60 min)

O laboratório é projetado para solidificar a compreensão da diferença prática entre o lançamento de instâncias em sub-redes públicas e privadas, e como a conectividade é estabelecida em cada caso.

**Roteiro:**

1.  **Preparação:** Certifique-se de ter uma VPC com pelo menos uma sub-rede pública e uma sub-rede privada (criadas no Módulo 1.3 ou em um módulo anterior). Tenha também um par de chaves EC2 e os Security Groups `WebServer-SG` e `DBServer-SG` (criados no Módulo 2.1).

2.  **Lançar Instância na Sub-rede Pública (`WebServer`):**
    *   **AMI:** Amazon Linux 2 (ou similar).
    *   **Tipo de Instância:** `t2.micro`.
    *   **Rede:** Selecione sua **sub-rede pública**.
    *   **Auto-assign Public IP:** **Enable**.
    *   **Security Group:** Associe o `WebServer-SG`.
    *   **Nome:** `WebServer-Lab`.
    *   Lance a instância.

3.  **Lançar Instância na Sub-rede Privada (`DBServer`):**
    *   **AMI:** Amazon Linux 2 (ou similar).
    *   **Tipo de Instância:** `t2.micro`.
    *   **Rede:** Selecione sua **sub-rede privada**.
    *   **Auto-assign Public IP:** **Disable**.
    *   **Security Group:** Associe o `DBServer-SG`.
    *   **Nome:** `DBServer-Lab`.
    *   Lance a instância.

4.  **Validar Conectividade:**
    *   **Acesso ao `WebServer-Lab`:**
        *   Obtenha o IP público do `WebServer-Lab` no console EC2.
        *   Tente fazer SSH para o `WebServer-Lab` do seu terminal local (`ssh -i <sua_chave.pem> ec2-user@<IP_PUBLICO_WEB_SERVER>`). Deve funcionar.
    *   **Acesso ao `DBServer-Lab`:**
        *   Observe que o `DBServer-Lab` **não tem um IP público**, validando seu isolamento da internet.
        *   **Acesso via `WebServer-Lab`:** Faça SSH para o `WebServer-Lab`. A partir do terminal do `WebServer-Lab`, tente se conectar ao `DBServer-Lab` usando seu IP privado (ex: `ping <IP_PRIVADO_DB_SERVER>` ou `nc -vz <IP_PRIVADO_DB_SERVER> 22`). Isso deve funcionar, validando que a comunicação interna da VPC e as regras do Security Group estão corretas.

Este processo valida a arquitetura de dois níveis e a eficácia da segmentação de rede, demonstrando como as instâncias são posicionadas e acessadas em diferentes tipos de sub-redes.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Posicionamento Estratégico:** Sempre lance recursos que não precisam de acesso de entrada da internet (bancos de dados, servidores de aplicação de back-end, caches) em sub-redes privadas sem IPs públicos. Isso minimiza a superfície de ataque.
*   **Acesso Administrativo Seguro:** Para acesso administrativo a instâncias em sub-redes privadas, utilize um Bastion Host (Módulo 3.2) ou, preferencialmente, o AWS Systems Manager Session Manager. Evite copiar chaves SSH para instâncias intermediárias.
*   **Elastic IPs para Estabilidade:** Use Elastic IPs (EIPs) para instâncias que exigem um ponto de extremidade de IP público estático e previsível (ex: servidores web, Load Balancers). Não confie em IPs públicos dinâmicos para servidores de longa duração ou de produção, pois eles mudam a cada reinício.
*   **Gerenciamento de EIPs:** Monitore seus EIPs. Há um pequeno custo por Elastic IPs que não estão associados a uma instância em execução. Libere os EIPs que não estão em uso para evitar custos desnecessários.
*   **Tags Consistentes:** Use tags para identificar claramente a função de cada instância (ex: `Role: WebServer`, `Environment: Production`, `Project: E-commerce`). Isso ajuda na organização, automação e rastreamento de custos.
*   **AMIs Otimizadas:** Utilize AMIs (Amazon Machine Images) padronizadas e otimizadas para segurança e performance. Considere criar suas próprias AMIs customizadas com suas configurações e softwares pré-instalados.
*   **Auto Scaling Groups:** Para aplicações que exigem alta disponibilidade e escalabilidade, utilize Auto Scaling Groups para gerenciar o lançamento e a terminação de instâncias automaticamente com base na demanda.