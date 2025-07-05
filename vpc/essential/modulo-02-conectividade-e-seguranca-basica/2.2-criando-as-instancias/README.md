# Módulo 2.2: Criando as Instâncias EC2 na VPC

**Tempo de Aula:** 30 minutos de teoria, 60 minutos de prática

## 1. Conceitos Fundamentais (Teoria Aprofundada)

### A Instância como um Inquilino da Rede
Uma instância EC2, em sua essência, é um servidor virtual. No entanto, ela não existe em um vácuo. Ela é um "inquilino" que reside em uma "vizinhança" (uma sub-rede) dentro de uma "cidade" (uma VPC). As propriedades e as regras dessa vizinhança ditam fundamentalmente o que a instância pode fazer e quem pode falar com ela.

O ato de lançar uma instância EC2 é um ato de **posicionamento de rede**. As decisões tomadas durante o lançamento determinam o contexto de rede da instância:

1.  **Seleção da VPC:** Define a "cidade" ou o limite de rede privado geral da instância.
2.  **Seleção da Sub-rede:** Esta é a decisão mais crítica. A sub-rede confere três propriedades à instância:
    -   **Localização Física (Zona de Disponibilidade):** A sub-rede está vinculada a uma única AZ, o que determina em qual data center físico a instância será executada. Esta é a base da resiliência.
    -   **Endereço IP Privado:** A instância recebe um endereço IP do bloco CIDR da sub-rede. Este é seu endereço permanente e imutável (enquanto a instância existir) para comunicação interna na VPC.
    -   **Roteabilidade Externa:** O comportamento de acesso à internet da instância é **herdado** da tabela de rotas associada à sub-rede. Se a tabela de rotas tem um caminho para um Internet Gateway, a instância tem o *potencial* de ser pública.

### A Mecânica do IP Público
Um endereço IP público na AWS não é configurado *na* instância. A instância em si só conhece seu IP privado. O IP público é uma propriedade gerenciada pela AWS no nível do gateway.

-   **Mapeamento 1:1 no IGW:** O Internet Gateway mantém uma tabela de mapeamento NAT 1:1. Quando você atribui um IP público a uma instância, o IGW cria uma entrada que mapeia `IP Público <-> IP Privado`.
-   **Tipos de IP Público:**
    1.  **IP Público Dinâmico:** Conveniente, mas efêmero. O endereço é liberado e um novo é atribuído se a instância for parada e iniciada. Isso o torna inadequado para servidores que precisam de um ponto de extremidade estável (como um servidor web com um registro DNS apontando para ele).
    2.  **Elastic IP (EIP):** Um IP público estático que você aloca para sua conta. Você tem controle total sobre seu ciclo de vida e pode reassociá-lo a diferentes instâncias. É a solução para pontos de extremidade estáveis.

## 2. Arquitetura e Casos de Uso

### Cenário Simples: Lançamento em Sub-rede Pública
Uma equipe de marketing precisa de um servidor web simples para uma campanha de curta duração. O servidor precisa ser acessível publicamente.

-   **Implementação:** A instância é lançada na sub-rede pública da VPC. Durante o lançamento, a opção **"Auto-assign public IP"** é definida como **"Enable"**. O Security Group `web-sg` é anexado.
-   **Justificativa:** Este é o caso de uso padrão para recursos que devem servir tráfego diretamente da internet. A combinação da sub-rede pública (que fornece a rota para o IGW) e o IP público (que fornece o mapeamento NAT no IGW) torna a instância acessível.

### Cenário Corporativo Robusto: Lançamento em Sub-rede Privada e o Padrão de Bastion Host
Uma empresa de saúde precisa implantar um servidor de aplicação que processa registros médicos eletrônicos (EHR). A conformidade com a HIPAA exige que este servidor seja completamente isolado da internet.

-   **Implementação:**
    1.  A instância `ehr-app-server` é lançada na **sub-rede privada** da VPC.
    2.  Durante o lançamento, a opção **"Auto-assign public IP"** é explicitamente definida como **"Disable"**. A instância não terá nenhum IP público.
    3.  O Security Group `ehr-app-sg` é anexado, permitindo tráfego apenas do load balancer da aplicação e do bastion host.
    4.  **O Problema do Acesso:** Como os administradores acessam este servidor para manutenção? Eles não podem se conectar diretamente. A solução é o padrão de **Bastion Host (ou Jump Server)**. Um Bastion Host é uma instância pequena e endurecida, lançada na sub-rede pública, cuja única finalidade é atuar como um ponto de "pulo" seguro. Os administradores se conectam via SSH ao Bastion Host (que tem seu próprio SG altamente restritivo), e a partir do Bastion, eles se conectam via SSH ao IP privado do `ehr-app-server`.
-   **Justificativa:** Este padrão garante que a superfície de ataque do servidor de aplicação seja minimizada. Ele não tem presença direta na internet. Todo o acesso administrativo é afunilado e controlado através de um único ponto de entrada seguro e auditável, atendendo aos requisitos de conformidade e segurança.

## 3. Melhores Práticas (AWS Well-Architected)

-   **Segurança:** Lance recursos que não precisam de acesso de entrada da internet (bancos de dados, servidores de aplicação de back-end) em sub-redes privadas sem IPs públicos. Use Bastion Hosts ou o AWS Systems Manager Session Manager para acesso administrativo seguro.
-   **Confiabilidade:** Use Elastic IPs para instâncias que exigem um ponto de extremidade de IP público estático. Não confie em IPs públicos dinâmicos para servidores de longa duração.
-   **Otimização de Custos:** Lembre-se de que há um pequeno custo por Elastic IPs que não estão associados a uma instância em execução. Libere os EIPs que não estão em uso.
-   **Excelência Operacional:** Use tags para identificar claramente a função de cada instância (ex: `Role: WebServer`, `Role: Database`). Use AMIs (Imagens de Máquina da Amazon) padronizadas e grupos de Auto Scaling para lançar instâncias de forma consistente.

## 4. Guia Prático (Laboratório)

O laboratório é projetado para solidificar a compreensão da diferença prática entre o lançamento em sub-redes públicas e privadas.
1.  **Lançar o `WebServer`:** O aluno o lança na sub-rede pública, habilita a atribuição de IP público e anexa o `Web-SG`.
2.  **Lançar o `DatabaseServer`:** O aluno o lança na sub-rede privada, desabilita a atribuição de IP público e anexa o `DB-SG`.
3.  **Testar a Conectividade:** O aluno executa uma série de testes:
    -   Tenta fazer SSH no IP público do `WebServer` (deve funcionar).
    -   Observa que o `DatabaseServer` não tem um IP público, validando seu isolamento da internet.
    -   Faz SSH no `WebServer` e, a partir dele, tenta se conectar (usando `ping` ou `nc`) ao IP privado do `DatabaseServer`. Isso deve funcionar, validando que a comunicação interna da VPC e as regras do Security Group estão corretas.
Este processo valida a arquitetura de dois níveis e a eficácia da segmentação de rede.
