# Módulo 3.2: Configurando um Bastion Host (Jump Server)

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Entender o padrão de arquitetura de **Ponto de Acesso Único (Single Point of Entry)**.
- Projetar e implementar um Bastion Host seguindo as melhores práticas de segurança (hardening).
- Dominar o uso do **encaminhamento de agente SSH (SSH Agent Forwarding)** para acesso seguro sem chaves.
- (Opcional) Comparar a abordagem do Bastion Host com a do AWS Systems Manager Session Manager.

---

## 1. O Padrão de Ponto de Acesso Único (Teoria - 60 min)

Em segurança de rede, um dos objetivos principais é **reduzir a superfície de ataque**. A superfície de ataque é a soma de todos os pontos de entrada e saída possíveis que um invasor pode tentar explorar. Cada servidor com um IP público, cada porta aberta para a internet, aumenta essa superfície.

O padrão de **Ponto de Acesso Único**, implementado através de um **Bastion Host** (ou Jump Server), é uma estratégia para minimizar drasticamente essa superfície de ataque para o gerenciamento administrativo da sua infraestrutura.

### O que é um Bastion Host?

Um Bastion Host é uma instância EC2 com um propósito único e específico: ser a **única porta de entrada** para administradores que precisam acessar outros servidores na rede privada. Em vez de expor a porta SSH (22) ou RDP (3389) de dezenas de servidores à internet, você expõe apenas a porta do Bastion Host, e apenas para um conjunto restrito de IPs.

**Fluxo de Conexão:**

`Administrador (IP Confiável) -> Internet -> Bastion Host (Sub-rede Pública) -> Rede Privada -> Instância de Destino (Sub-rede Privada)`

### Projetando um Bastion Host Seguro (Hardening)

Como o Bastion Host é a porta de entrada, ele é um alvo de alto valor e deve ser o servidor mais protegido e "endurecido" (hardened) da sua infraestrutura.

1.  **Isolamento de Rede:**
    -   Deve residir em uma **sub-rede pública**.
    -   Seu **Security Group** é a defesa mais crítica. A regra de entrada para a porta 22/3389 deve ser restrita ao menor conjunto possível de IPs de origem (`/32`). **Nunca use `0.0.0.0/0`**.
    -   A regra de saída deve permitir conexões apenas para as portas 22/3389 dos blocos CIDR das suas sub-redes privadas.

2.  **Mínimo Privilégio no Host:**
    -   **Tamanho da Instância:** Use o menor tipo de instância possível (ex: `t2.micro`). Ele só precisa lidar com algumas conexões SSH, que consomem pouquíssimos recursos.
    -   **Software Mínimo:** A imagem do SO deve ser mínima. Não instale nenhum software desnecessário (servidores web, bancos de dados, etc.). Cada software adicional é uma potencial vulnerabilidade.
    -   **Hardening do SO:** Aplique patches de segurança regularmente, desabilite logins por senha (use apenas chaves SSH), e configure ferramentas de detecção de intrusão (como `fail2ban`).

3.  **Mínimo Privilégio no IAM:**
    -   O Bastion Host deve ter uma **IAM Role sem nenhuma permissão** anexada. Ele não precisa interagir com as APIs da AWS; sua única função é encaminhar pacotes de rede.

### O Problema das Chaves SSH e a Solução do Agente

Um erro comum e perigoso é copiar sua chave privada (`.pem`) para o Bastion Host para então usá-la para se conectar às instâncias privadas. Isso quebra todo o modelo de segurança. Se o Bastion for comprometido, o invasor rouba a chave e ganha acesso a toda a sua rede.

**SSH Agent Forwarding** resolve isso. O agente SSH é um programa auxiliar que roda no seu computador local e mantém suas chaves privadas em memória.

-   **Como Funciona:**
    1.  Você adiciona sua chave ao agente local (`ssh-add`).
    2.  Você se conecta ao Bastion com a flag `-A`. Isso cria um canal de comunicação seguro de volta para o seu agente local.
    3.  Quando, de dentro do Bastion, você tenta se conectar a uma instância privada, o cliente SSH no Bastion não procura por uma chave localmente. Em vez disso, ele envia a solicitação de autenticação através do canal seguro para o **seu agente no seu computador**.
    4.  Seu agente local realiza a operação criptográfica com sua chave privada e retorna a resposta, completando a autenticação.
    -   **Resultado:** Sua chave privada **nunca sai do seu computador**. O Bastion apenas atua como um proxy para a autenticação.

### Alternativa Moderna: AWS Systems Manager Session Manager

O Session Manager é um serviço da AWS que oferece uma alternativa ainda mais segura e gerenciada ao Bastion Host. 
-   **Como Funciona:** Ele usa um agente (o SSM Agent, instalado por padrão na maioria das AMIs da AWS) na instância de destino. Você se autentica na AWS (via console ou CLI) e o Session Manager estabelece um túnel seguro para o shell da instância através do endpoint do SSM. 
-   **Vantagens:**
    -   Não requer que a instância tenha um IP público.
    -   Não requer a abertura de portas de entrada (como a 22) no Security Group.
    -   O acesso é controlado via políticas IAM.
    -   As sessões podem ser logadas no S3 ou CloudWatch.
-   **Desvantagem:** Requer que as instâncias tenham o SSM Agent e conectividade com o endpoint do SSM (via internet ou VPC Endpoint de Interface).

---

## 2. Deploy e Configuração de Bastion Host (Prática - 60 min)

Neste laboratório, vamos configurar um Bastion Host e usar o SSH Agent Forwarding para acessar de forma segura nossa instância `Lab-DBServer`.

### Roteiro Prático

**Passo 1: Criar o Security Group do Bastion**
1.  Crie um novo Security Group: `Name: Bastion-SG`, na sua `Lab-VPC`.
2.  **Inbound rules:**
    -   `Type: SSH (22)`, `Source: My IP` (O console preencherá com seu IP `/32`).
3.  **Outbound rules:**
    -   `Type: SSH (22)`, `Destination: CIDR da sua sub-rede privada` (ex: `10.0.2.0/24`).

**Passo 2: Lançar a Instância do Bastion Host**
1.  Lance uma instância `t2.micro` (Amazon Linux 2) chamada `BastionHost`.
2.  **Network settings:**
    -   **VPC:** `Lab-VPC`
    -   **Subnet:** **Sub-rede PÚBLICA**.
    -   **Auto-assign public IP:** **Enable**.
    -   **Firewall:** Selecione o `Bastion-SG`.
3.  **IAM instance profile:** Não anexe nenhuma role.
4.  Lance a instância usando seu par de chaves.

**Passo 3: Configurar o Acesso da Instância Privada**
1.  Vá para o Security Group da sua instância privada (`DB-SG`).
2.  Edite as **Inbound rules**. Adicione uma nova regra:
    -   `Type: SSH (22)`, `Source: Bastion-SG`.
3.  Salve a regra. Agora, apenas o Bastion pode fazer SSH na sua instância de banco de dados.

**Passo 4: Conectar Usando SSH Agent Forwarding**

1.  **Adicionar sua chave ao Agente SSH (no seu computador local):**
    -   Abra um terminal e execute: `ssh-add /caminho/para/sua-chave.pem`.

2.  **Conectar ao Bastion com Forwarding Habilitado:**
    -   Pegue o IP público do seu `BastionHost`.
    -   Use a flag `-A` para habilitar o agent forwarding:
        ```bash
        ssh -A ec2-user@IP_PUBLICO_DO_BASTION
        ```

3.  **Pular para a Instância Privada:**
    -   Agora você está no shell do `BastionHost`.
    -   Pegue o **IP privado** da sua instância `Lab-DBServer`.
    -   Conecte-se a ela a partir do Bastion:
        ```bash
        ssh ec2-user@IP_PRIVADO_DO_DBSERVER
        ```
    -   A conexão deve ser estabelecida sem pedir uma chave, pois seu agente local cuidou da autenticação.

4.  **Verificação:**
    -   Execute o comando `hostname`. O resultado deve ser o nome do host do `Lab-DBServer`.

Você implementou com sucesso o padrão de Ponto de Acesso Único, permitindo o gerenciamento seguro de recursos isolados sem expor chaves privadas ou aumentar desnecessariamente a superfície de ataque.