# Módulo 3.3: Ajustando Permissões com IAM Roles para VPC

**Tempo de Aula:** 30 minutos de teoria, 30 minutos de prática

## Pré-requisitos

*   Conhecimento básico de AWS IAM (usuários, grupos, políticas).
*   Familiaridade com o serviço EC2 e o conceito de instâncias.
*   Compreensão da importância da segurança em nuvem.

## Objetivos

*   Compreender o problema de segurança de armazenar credenciais estáticas em instâncias EC2.
*   Entender o conceito de delegação de confiança e o papel das IAM Roles para máquinas.
*   Aprender a criar e configurar IAM Roles com políticas de confiança e permissão adequadas.
*   Anexar IAM Roles a instâncias EC2 para conceder permissões de forma segura.
*   Validar o acesso a serviços AWS a partir de uma instância EC2 usando IAM Roles.
*   Discutir o Princípio do Menor Privilégio na prática com IAM Roles.

---

## 1. Conceitos Fundamentais: O Problema da Identidade da Máquina (Teoria - 30 min)

Em qualquer sistema de computação, a **identidade** é o pré-requisito para o **acesso**. Para humanos, usamos nomes de usuário e senhas. Mas como uma máquina (uma instância EC2) prova sua identidade para outro serviço (como a API do S3) para obter acesso?

A solução ingênua é dar à máquina um par de "nome de usuário e senha" de longa duração - um **Access Key ID** e uma **Secret Access Key**. Armazenar essas credenciais estáticas no disco de uma instância é uma das práticas de segurança mais perigosas na nuvem. É o equivalente a escrever a senha do cofre em um post-it e colá-lo na porta do cofre. Se a instância for comprometida, as credenciais são roubadas, e o invasor ganha acesso a tudo o que aquelas credenciais permitem, de qualquer lugar do mundo, de forma permanente.

### O Princípio da Delegação de Confiança com IAM Roles

A solução segura para o problema da identidade da máquina é a **delegação de confiança**. Em vez de dar à máquina uma identidade permanente, nós damos a ela a capacidade de **assumir temporariamente uma identidade** quando necessário. Essa identidade temporária é uma **IAM Role**.

Uma **IAM Role** é uma construção do AWS Identity and Access Management (IAM) que define um conjunto de permissões. Ela não está associada a um usuário ou máquina específica. Em vez disso, ela é projetada para ser **assumida** por entidades confiáveis (usuários, serviços AWS, ou até mesmo outras contas AWS).

*   **Relação de Confiança (Trust Policy):** A parte mais importante de uma role é sua política de confiança. Este documento JSON define **quem** pode assumir a role. Para o nosso caso de instâncias EC2, a política de confiança diria: "Eu confio no serviço EC2 (`ec2.amazonaws.com`) para assumir esta role".
*   **Política de Permissão (Permissions Policy):** Esta é a política IAM padrão que define **o que** a entidade pode fazer *depois* de assumir a role (ex: `s3:GetObject`, `sqs:SendMessage`).

O **AWS Security Token Service (STS)** é o serviço que fica no coração deste processo. Quando uma instância EC2 precisa de permissões, ela contata o serviço de metadados local, que por sua vez chama o STS. O STS valida que o serviço EC2 tem permissão para assumir a role solicitada e, em caso afirmativo, emite **credenciais de segurança temporárias** (uma Access Key, uma Secret Key e um Session Token). Essas credenciais têm um tempo de vida curto (geralmente algumas horas) e são rotacionadas automaticamente, eliminando o risco das credenciais estáticas.

## 2. Arquitetura e Casos de Uso: IAM Roles em Cenários Reais

### Cenário Simples: Uma Aplicação Lendo de um Bucket S3

*   **Descrição:** Uma aplicação simples rodando em uma instância EC2 precisa exibir imagens que estão armazenadas em um bucket S3 privado. A aplicação precisa de permissão para ler (fazer `GetObject`) desses objetos.
*   **Implementação:**
    1.  Uma IAM Role chamada `WebApp-S3-ReadOnly-Role` é criada.
    2.  A política de confiança da role permite que o serviço EC2 a assuma (`ec2.amazonaws.com`).
    3.  A política de permissão gerenciada pela AWS `AmazonS3ReadOnlyAccess` (ou uma política customizada mais granular para o bucket específico) é anexada à role.
    4.  A instância EC2 é lançada com esta IAM Role anexada (através de um Instance Profile).
*   **Justificativa:** A aplicação, usando o SDK da AWS (que automaticamente busca credenciais do serviço de metadados da instância), obterá as credenciais temporárias e poderá ler as imagens do S3. Nenhuma chave de acesso é armazenada na instância. Se a instância for comprometida, o invasor só poderá ler do S3, e apenas por um tempo limitado até que as credenciais expirem. Ele não poderá deletar nada ou acessar outros serviços, minimizando o raio de explosão.

### Cenário Corporativo Robusto: Acesso Granular a Múltiplos Serviços para Microsserviços

*   **Descrição:** Um microsserviço de processamento de vídeo, rodando em um cluster de EC2, precisa realizar um fluxo de trabalho complexo:
    1.  Ler um vídeo de um bucket S3 de entrada.
    2.  Enviar uma mensagem para uma fila SQS para notificar sobre o início do processamento.
    3.  Processar o vídeo.
    4.  Gravar o vídeo processado em um bucket S3 de saída.
    5.  Gravar metadados sobre o processamento em uma tabela do DynamoDB.
*   **Implementação:** Uma única e altamente específica IAM Role é criada para este serviço, `VideoProcessing-Service-Role`.
    *   **Política de Confiança:** Permite que o serviço EC2 a assuma.
    *   **Política de Permissão:** Uma política **customizada e inline** é criada, seguindo rigorosamente o Princípio do Menor Privilégio:
        ```json
        {
            "Version": "2012-10-17",
            "Statement": [
                { "Effect": "Allow", "Action": "s3:GetObject", "Resource": "arn:aws:s3:::video-input-bucket/*" },
                { "Effect": "Allow", "Action": "sqs:SendMessage", "Resource": "arn:aws:sqs:us-east-1:123456789012:video-processing-queue" },
                { "Effect": "Allow", "Action": "s3:PutObject", "Resource": "arn:aws:s3:::video-output-bucket/*" },
                { "Effect": "Allow", "Action": ["dynamodb:PutItem", "dynamodb:UpdateItem"], "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/video-metadata-table" }
            ]
        }
        ```
*   **Justificativa:** Esta política concede **exatamente** as permissões necessárias, e nada mais. A role não pode deletar objetos, ler de outros buckets ou acessar qualquer outro serviço. Se uma instância neste cluster for comprometida, o raio de explosão é extremamente limitado, pois as credenciais temporárias só permitem as ações definidas e para os recursos específicos. Esta abordagem granular é a base da segurança no nível da aplicação na AWS.

## 3. Guia Prático (Laboratório - 30 min)

O laboratório é projetado para demonstrar a facilidade e a segurança do uso de IAM Roles em contraste com o anti-padrão de credenciais estáticas. O aluno verá como uma instância pode acessar serviços AWS sem ter nenhuma credencial configurada diretamente nela.

**Roteiro:**

1.  **Criar um Bucket S3 de Teste:**
    *   Crie um bucket S3 com um nome único (ex: `my-lab-iam-role-test-bucket-123`).
    *   Faça upload de um arquivo de texto simples para ele (ex: `hello.txt` com o conteúdo "Hello from S3").

2.  **Criar a IAM Role (`EC2-S3-ReadOnly-Role`):**
    *   Navegue até o console da AWS > IAM > Roles > Create role.
    *   **Trusted entity type:** `AWS service` > `EC2`.
    *   Clique em Next.
    *   **Add permissions:** Pesquise por `AmazonS3ReadOnlyAccess` e selecione-a.
    *   Clique em Next.
    *   **Role name:** `EC2-S3-ReadOnly-Role`.
    *   Clique em Create role.

3.  **Anexar a Role a uma Instância EC2:**
    *   Lance uma nova instância EC2 (`t2.micro`, Amazon Linux 2) ou selecione uma existente.
    *   Durante o lançamento, na seção "Advanced details" ou "Configure instance details", em "IAM instance profile", selecione a `EC2-S3-ReadOnly-Role` que você acabou de criar.
    *   Se for uma instância existente, selecione-a, vá em Actions > Security > Modify IAM role e anexe a role.

4.  **Validar o Acesso a partir da Instância:**
    *   Faça SSH na instância EC2 onde a role foi anexada.
    *   Execute o comando AWS CLI para listar o conteúdo do seu bucket S3:
        ```bash
        aws s3 ls s3://my-lab-iam-role-test-bucket-123/
        ```
    *   **Resultado esperado:** O comando deve funcionar, listando o arquivo `hello.txt`, sem que você tenha configurado nenhuma credencial na instância.

5.  **Analisar e Desmistificar (Discussão):**
    *   **Ausência de Credenciais:** Verifique a ausência do arquivo `~/.aws/credentials` na instância para provar que nenhuma chave estática foi usada.
    *   **Serviço de Metadados:** Explique que o SDK da AWS (usado pelo `aws s3 ls`) obtém as credenciais temporárias do serviço de metadados da instância. Você pode ver essas credenciais executando (dentro da instância):
        ```bash
        curl http://169.254.169.254/latest/meta-data/iam/security-credentials/EC2-S3-ReadOnly-Role
        ```
        Isso revela as credenciais temporárias (AccessKeyId, SecretAccessKey, Token) e seu tempo de expiração. Este passo desmistifica o processo e revela a "mágica" segura que acontece nos bastidores.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **SEMPRE use IAM Roles para Instâncias EC2:** Esta é a regra de segurança mais fundamental para conceder permissões a recursos computacionais na AWS. **NUNCA** armazene credenciais estáticas (Access Key ID e Secret Access Key) diretamente em uma instância EC2 ou em código-fonte.
*   **Princípio do Menor Privilégio:** Crie políticas customizadas que concedem apenas as permissões estritamente necessárias para a tarefa em questão. Evite usar políticas gerenciadas pela AWS (como `AdministratorAccess` ou `PowerUserAccess`) em roles para suas aplicações, a menos que seja absolutamente essencial e bem justificado.
*   **Nomenclatura Clara:** Dê nomes claros e descritivos às suas roles para que sua finalidade seja óbvia (ex: `EC2-Role-For-WebApp-S3-Access`, `Lambda-Role-For-DynamoDB-Write`).
*   **Auditoria com CloudTrail:** Monitore as ações do IAM e as tentativas de acesso negadas no CloudTrail para identificar falhas de configuração ou tentativas de acesso não autorizado. O CloudTrail registra quando uma role é assumida e quais ações foram realizadas.
*   **Rotação Automática de Credenciais:** As credenciais temporárias fornecidas pelo STS são automaticamente rotacionadas, o que reduz significativamente o risco de credenciais comprometidas.
*   **Separar Responsabilidades:** Crie roles diferentes para diferentes aplicações ou microsserviços, mesmo que eles rodem na mesma instância. Isso permite um controle de acesso mais granular e limita o raio de explosão em caso de comprometimento.