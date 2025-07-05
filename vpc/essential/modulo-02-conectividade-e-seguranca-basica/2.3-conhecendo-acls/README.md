# Módulo 2.3: Conhecendo Network ACLs (NACLs)

**Tempo de Aula:** 30 minutos de teoria, 30 minutos de prática

## 1. Conceitos Fundamentais (Teoria Aprofundada)

### O Firewall como um Guarda de Fronteira
Continuando nossa analogia do firewall como um porteiro, se um Security Group (stateful) é o porteiro inteligente do seu prédio, uma **Network ACL (stateless)** é o guarda de fronteira de um país. O guarda de fronteira não se importa se você é um residente conhecido ou se ele o viu sair há cinco minutos. Cada vez que você cruza a fronteira, em qualquer direção, ele verifica seus documentos (os pacotes) em relação a um conjunto de regras explícitas. É uma verificação nova e independente a cada vez.

Um firewall **stateless** não mantém uma tabela de estado de conexões. Ele examina cada pacote de dados isoladamente e o compara com uma lista de regras (uma Access Control List - ACL). A primeira regra na lista que corresponder ao pacote é aplicada, e o processo para.

-   **A Implicação do Stateless:** A consequência mais importante disso é que o tráfego de **resposta** deve ser explicitamente permitido. Se você criar uma regra de entrada para permitir que o tráfego chegue na porta 443, você também deve criar uma regra de **saída** para permitir que a resposta (que vem da porta 443 e vai para uma porta de alta numeração no cliente) saia. Esquecer a regra de resposta é a causa mais comum de problemas com NACLs.

### Network ACLs: O Firewall da Sub-rede
As **Network ACLs (NACLs)** são a implementação da AWS de um firewall stateless. Elas operam no nível da **sub-rede**, atuando como a primeira e a última linha de defesa para todo o tráfego que entra ou sai de um segmento de rede.

-   **Processamento Ordenado:** As regras em uma NACL são numeradas e processadas em ordem, do menor número para o maior. É uma boa prática usar incrementos (100, 110, 120) para deixar espaço para inserir novas regras no futuro.
-   **Regras de `Allow` e `Deny`:** Diferente dos Security Groups, as NACLs suportam regras de `Deny`. Isso as torna a ferramenta ideal para **blacklisting** explícito.
-   **Negação Implícita Final:** Cada NACL termina com uma regra `*` (asterisco) imutável que nega todo o tráfego que não correspondeu a nenhuma regra anterior.

## 2. Arquitetura e Casos de Uso

### Cenário Simples: Bloqueando um IP Malicioso
Uma pequena empresa percebe em seus logs que um endereço IP específico (`203.0.113.5`) está constantemente tentando forçar o acesso SSH ao seu servidor web. 

-   **Implementação:** Em vez de adicionar uma regra de `Deny` ao firewall do SO (o que só protege aquela instância), o administrador vai para a NACL associada à sua sub-rede pública. Ele adiciona uma nova regra de entrada com um número baixo (ex: `Rule #90`). A regra especifica `Source: 203.0.113.5/32`, `Protocol: All`, `Action: DENY`.
-   **Justificativa:** Esta é a maneira mais eficiente de lidar com a ameaça. O tráfego do IP malicioso agora é descartado na fronteira da sub-rede, antes mesmo de chegar perto do Security Group ou da instância. Isso protege todos os recursos na sub-rede e reduz a carga de processamento de logs de tentativas de login falhas.

### Cenário Corporativo Robusto: Conformidade e Isolamento de DMZ
Uma empresa precisa hospedar um servidor SFTP legado que será acessado por parceiros externos. A política de segurança da empresa dita que este tipo de serviço deve residir em uma zona desmilitarizada (DMZ) e que o tráfego da DMZ para a rede interna deve ser estritamente controlado.

-   **Implementação:**
    1.  Uma sub-rede `DMZ-Subnet` é criada.
    2.  Uma NACL customizada, `DMZ-NACL`, é criada e associada a ela.
    3.  A `DMZ-NACL` é configurada com regras de entrada que permitem a porta 22 (SFTP) apenas dos IPs dos parceiros e negam todo o resto.
    4.  Mais importante, a `DMZ-NACL` é configurada com regras de **saída** que proíbem explicitamente que a sub-rede inicie conexões com os blocos CIDR das sub-redes de aplicação e de banco de dados internas. A única saída permitida é o tráfego de resposta para os parceiros.
-   **Justificativa:** A NACL atua como um controle de perímetro rigoroso que impõe a política de isolamento da DMZ. Mesmo que o servidor SFTP seja comprometido, a NACL impediria que o invasor usasse o servidor comprometido para iniciar ataques contra a rede interna. O Security Group do servidor SFTP ainda seria usado para controle refinado, mas a NACL fornece a camada de isolamento de rede mais ampla.

## 3. Melhores Práticas (AWS Well-Architected)

-   **Segurança:** Use as NACLs como parte de uma estratégia de **Defesa em Profundidade**. Elas não substituem os Security Groups; elas os complementam. Use NACLs para regras de bloqueio amplas e de perímetro (blacklisting) e SGs para controle de acesso refinado e específico da aplicação (whitelisting).
-   **Excelência Operacional:** Mantenha suas NACLs o mais simples possível. A maioria das sub-redes pode funcionar perfeitamente com a NACL padrão (que permite tudo), deixando o controle de segurança para os Security Groups. Use NACLs customizadas apenas quando você tiver um requisito explícito para `Deny` ou para controle de tráfego no nível da sub-rede.
-   **Confiabilidade:** Lembre-se sempre da natureza stateless das NACLs. Ao adicionar uma regra de entrada, sempre considere se uma regra de saída correspondente é necessária para o tráfego de resposta. Esquecer isso é uma causa comum de interrupções de conectividade difíceis de diagnosticar.

## 4. Guia Prático (Laboratório)

O laboratório se concentra no caso de uso principal e mais claro das NACLs: blacklisting. O aluno irá:
1.  Criar uma NACL customizada.
2.  Observar que, por padrão, ela nega tudo.
3.  Adicionar regras explícitas para permitir o tráfego web (HTTP/HTTPS) e SSH, incluindo as regras de resposta de saída necessárias.
4.  Adicionar uma regra de `DENY` com um número menor para bloquear um IP fictício.
5.  Associar a NACL à sub-rede pública.
Este exercício demonstra o poder da regra `DENY` e a ordem de processamento, solidificando o entendimento da NACL como um firewall de perímetro.
