# Módulo 2.3: Conhecendo Network ACLs (NACLs)

**Tempo de Aula:** 30 minutos de teoria, 30 minutos de prática

## Pré-requisitos

*   Conhecimento básico de redes TCP/IP (portas, protocolos, CIDR).
*   Familiaridade com o conceito de sub-redes e Security Groups (Módulo 2.1).
*   Compreensão da diferença entre firewalls stateful e stateless.

## Objetivos

*   Compreender a Network ACL (NACL) como um firewall stateless em nível de sub-rede.
*   Entender a ordem de processamento das regras em uma NACL e a importância das regras numeradas.
*   Aprender a configurar regras de entrada (inbound) e saída (outbound) em NACLs, incluindo regras de `ALLOW` e `DENY`.
*   Discutir os casos de uso ideais para NACLs, como blacklisting e controle de perímetro.
*   Realizar uma configuração prática de NACL para bloquear tráfego específico.

---

## 1. Conceitos Fundamentais: O Firewall como um Guarda de Fronteira (Teoria - 30 min)

Continuando nossa analogia do firewall como um porteiro, se um Security Group (stateful) é o porteiro inteligente do seu prédio, uma **Network ACL (stateless)** é o guarda de fronteira de um país. O guarda de fronteira não se importa se você é um residente conhecido ou se ele o viu sair há cinco minutos. Cada vez que você cruza a fronteira, em qualquer direção, ele verifica seus documentos (os pacotes) em relação a um conjunto de regras explícitas. É uma verificação nova e independente a cada vez.

### Firewall Stateless (Sem Estado)

Um firewall **stateless** não mantém uma tabela de estado de conexões. Ele examina cada pacote de dados isoladamente e o compara com uma lista de regras (uma Access Control List - ACL). A primeira regra na lista que corresponder ao pacote é aplicada, e o processo para. Se nenhum pacote corresponder a uma regra, a regra de negação implícita no final da lista é aplicada.

*   **A Implicação do Stateless:** A consequência mais importante disso é que o tráfego de **resposta** deve ser explicitamente permitido. Se você criar uma regra de entrada para permitir que o tráfego chegue na porta 443, você também deve criar uma regra de **saída** para permitir que a resposta (que vem da porta 443 e vai para uma porta de alta numeração no cliente) saia. Esquecer a regra de resposta é a causa mais comum de problemas com NACLs e pode levar a interrupções de conectividade difíceis de diagnosticar.

### Network ACLs: O Firewall da Sub-rede na AWS

As **Network ACLs (NACLs)** são a implementação da AWS de um firewall stateless. Elas operam no nível da **sub-rede**, atuando como a primeira e a última linha de defesa para todo o tráfego que entra ou sai de um segmento de rede. Uma NACL pode ser associada a múltiplas sub-redes, mas uma sub-rede só pode ter uma NACL associada.

*   **Processamento Ordenado:** As regras em uma NACL são numeradas (de 1 a 32766) e processadas em ordem, do menor número para o maior. A primeira regra que corresponde ao tráfego é aplicada, e nenhuma outra regra é avaliada. É uma boa prática usar incrementos (100, 110, 120) para deixar espaço para inserir novas regras no futuro.
*   **Regras de `Allow` e `Deny`:** Diferente dos Security Groups, as NACLs suportam regras de `Deny` explícitas. Isso as torna a ferramenta ideal para **blacklisting** (bloquear tráfego de IPs específicos ou intervalos de IP).
*   **Negação Implícita Final:** Cada NACL termina com uma regra `*` (asterisco) imutável que nega todo o tráfego que não correspondeu a nenhuma regra anterior. Se você criar uma NACL customizada, ela inicialmente nega todo o tráfego até que você adicione regras de `ALLOW`.

## 2. Arquitetura e Casos de Uso: NACLs em Cenários Reais

### Cenário Simples: Bloqueando um IP Malicioso

*   **Descrição:** Uma pequena empresa percebe em seus logs que um endereço IP específico (`203.0.113.5`) está constantemente tentando forçar o acesso SSH ao seu servidor web. Eles querem bloquear esse IP em nível de rede para proteger todos os recursos na sub-rede.
*   **Implementação:** Em vez de adicionar uma regra de `Deny` ao firewall do SO (o que só protege aquela instância), o administrador vai para a NACL associada à sua sub-rede pública. Ele adiciona uma nova regra de entrada com um número baixo (ex: `Rule #90`). A regra especifica `Source: 203.0.113.5/32`, `Protocol: All`, `Action: DENY`.
*   **Justificativa:** Esta é a maneira mais eficiente de lidar com a ameaça. O tráfego do IP malicioso agora é descartado na fronteira da sub-rede, antes mesmo de chegar perto do Security Group ou da instância. Isso protege todos os recursos na sub-rede e reduz a carga de processamento de logs de tentativas de login falhas. A natureza stateless da NACL garante que cada pacote desse IP seja avaliado e descartado.

### Cenário Corporativo Robusto: Conformidade e Isolamento de DMZ (Zona Desmilitarizada)

*   **Descrição:** Uma empresa precisa hospedar um servidor SFTP legado que será acessado por parceiros externos. A política de segurança da empresa dita que este tipo de serviço deve residir em uma zona desmilitarizada (DMZ) e que o tráfego da DMZ para a rede interna deve ser estritamente controlado para evitar movimentos laterais em caso de comprometimento.
*   **Implementação:**
    1.  Uma sub-rede `DMZ-Subnet` é criada para o servidor SFTP.
    2.  Uma NACL customizada, `DMZ-NACL`, é criada e associada a ela.
    3.  A `DMZ-NACL` é configurada com regras de entrada que permitem a porta 22 (SFTP) apenas dos IPs dos parceiros e negam todo o resto.
    4.  Mais importante, a `DMZ-NACL` é configurada com regras de **saída** que proíbem explicitamente que a sub-rede inicie conexões com os blocos CIDR das sub-redes de aplicação e de banco de dados internas. A única saída permitida é o tráfego de resposta para os parceiros e, talvez, para serviços de monitoramento ou logs.
*   **Justificativa:** A NACL atua como um controle de perímetro rigoroso que impõe a política de isolamento da DMZ. Mesmo que o servidor SFTP seja comprometido, a NACL impediria que o invasor usasse o servidor comprometido para iniciar ataques contra a rede interna. O Security Group do servidor SFTP ainda seria usado para controle refinado em nível de instância, mas a NACL fornece a camada de isolamento de rede mais ampla e robusta.

## 3. Guia Prático (Laboratório - 30 min)

O laboratório se concentra no caso de uso principal e mais claro das NACLs: blacklisting e a necessidade de regras de resposta. O aluno irá:

1.  **Criar uma NACL customizada:**
    *   Navegue até o console da AWS > VPC > Network ACLs > Create network ACL.
    *   Dê um nome (ex: `Lab-Public-NACL`) e associe-a à sua VPC de laboratório.
    *   Observe que, por padrão, as regras de entrada e saída são `DENY ALL` (regra `*`).

2.  **Adicionar Regras de `ALLOW` para Tráfego Web e SSH:**
    *   **Regras de Entrada (Inbound Rules):**
        *   `Rule #100`: `ALLOW TCP 80` from `0.0.0.0/0` (HTTP)
        *   `Rule #110`: `ALLOW TCP 443` from `0.0.0.0/0` (HTTPS)
        *   `Rule #120`: `ALLOW TCP 22` from `<SEU_IP_LOCAL>/32` (SSH do seu IP)
        *   `Rule #130`: `ALLOW TCP 1024-65535` from `0.0.0.0/0` (Portas efêmeras para tráfego de resposta de saída).
    *   **Regras de Saída (Outbound Rules):**
        *   `Rule #100`: `ALLOW TCP 80` to `0.0.0.0/0`
        *   `Rule #110`: `ALLOW TCP 443` to `0.0.0.0/0`
        *   `Rule #120`: `ALLOW TCP 22` to `<SEU_IP_LOCAL>/32`
        *   `Rule #130`: `ALLOW TCP 1024-65535` to `0.0.0.0/0` (Portas efêmeras para tráfego de resposta de entrada).

3.  **Adicionar uma Regra de `DENY` (Blacklisting):**
    *   **Regra de Entrada (Inbound Rules):**
        *   `Rule #90`: `DENY All Traffic` from `203.0.113.5/32` (IP fictício de um atacante).
    *   **Discussão:** Por que o número da regra é 90? (Para ser avaliada antes das regras de `ALLOW`).

4.  **Associar a NACL à Sub-rede Pública:**
    *   Vá para a aba "Subnet Associations" da sua NACL e edite para associá-la à sua sub-rede pública de laboratório.

5.  **Testar e Validar:**
    *   Lance uma instância EC2 na sub-rede pública associada a esta NACL.
    *   Tente acessar a instância via HTTP/HTTPS e SSH do seu IP (deve funcionar).
    *   (Opcional) Se você puder simular tráfego de `203.0.113.5`, observe que ele será bloqueado.

Este exercício demonstra o poder da regra `DENY` e a ordem de processamento, solidificando o entendimento da NACL como um firewall de perímetro.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **NACLs Complementam SGs:** Use as NACLs como parte de uma estratégia de **Defesa em Profundidade**. Elas não substituem os Security Groups; elas os complementam. Use NACLs para regras de bloqueio amplas e de perímetro (blacklisting) e SGs para controle de acesso refinado e específico da aplicação (whitelisting).
*   **Mantenha Simples:** Mantenha suas NACLs o mais simples possível. A maioria das sub-redes pode funcionar perfeitamente com a NACL padrão (que permite tudo), deixando o controle de segurança para os Security Groups. Use NACLs customizadas apenas quando você tiver um requisito explícito para `Deny` ou para controle de tráfego no nível da sub-rede.
*   **Ordem das Regras é Crucial:** Lembre-se que as NACLs processam as regras em ordem numérica (do menor para o maior). Coloque as regras `DENY` mais específicas com números menores para garantir que sejam avaliadas antes das regras `ALLOW` mais amplas.
*   **NACLs Stateless:** Sempre, sempre, sempre lembre-se da natureza stateless das NACLs. Ao adicionar uma regra de entrada, sempre considere se uma regra de saída correspondente é necessária para o tráfego de resposta (e vice-versa). Esquecer isso é uma causa comum de interrupções de conectividade difíceis de diagnosticar.
*   **Portas Efêmeras:** Ao configurar regras de NACL, lembre-se das portas efêmeras (1024-65535) que os clientes usam para iniciar conexões. Você precisará permitir o tráfego de resposta nessas portas.
*   **Documentação e Nomenclatura:** Dê nomes claros às suas NACLs e adicione descrições detalhadas às suas regras. Isso é vital para a manutenção e auditoria.
*   **Monitoramento:** Utilize VPC Flow Logs (Módulo 3.1) para monitorar o tráfego que é permitido ou negado por suas NACLs. Isso ajuda a identificar tentativas de acesso não autorizado e a depurar problemas de conectividade.