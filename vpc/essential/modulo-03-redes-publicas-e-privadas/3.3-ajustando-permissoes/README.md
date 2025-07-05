# Módulo 3.3: Ajustando Permissões com IAM Roles para VPC

**Tempo de Aula:** 30 minutos de teoria, 30 minutos de prática

## 1. Conceitos Fundamentais (Teoria Aprofundada)

### O Problema da Identidade da Máquina
Em qualquer sistema de computação, a **identidade** é o pré-requisito para o **acesso**. Para humanos, usamos nomes de usuário e senhas. Mas como uma máquina (uma instância EC2) prova sua identidade para outro serviço (como a API do S3) para obter acesso? 

A solução ingênua é dar à máquina um par de "nome de usuário e senha" de longa duração - um **Access Key ID** e uma **Secret Access Key**. Armazenar essas credenciais estáticas no disco de uma instância é uma das práticas de segurança mais perigosas na nuvem. É o equivalente a escrever a senha do cofre em um post-it e colá-lo na porta do cofre. Se a instância for comprometida, as credenciais são roubadas, e o invasor ganha acesso a tudo o que aquelas credenciais permitem, de qualquer lugar do mundo.

### O Princípio da Delegação de Confiança
A solução segura para o problema da identidade da máquina é a **delegação de confiança**. Em vez de dar à máquina uma identidade permanente, nós damos a ela a capacidade de **assumir temporariamente uma identidade** quando necessário. Essa identidade temporária é uma **IAM Role**.

Uma **IAM Role** é uma construção do AWS Identity and Access Management (IAM) que define um conjunto de permissões. Ela não está associada a um usuário ou máquina específica. Em vez disso, ela é projetada para ser **assumida** por entidades confiáveis.

-   **Relação de Confiança (Trust Policy):** A parte mais importante de uma role é sua política de confiança. Este documento JSON define **quem** pode assumir a role. Para o nosso caso, a política de confiança diria: "Eu confio no serviço EC2 (`ec2.amazonaws.com`) para assumir esta role".
-   **Política de Permissão (Permissions Policy):** Esta é a política IAM padrão que define **o que** a entidade pode fazer *depois* de assumir a role (ex: `s3:GetObject`, `sqs:SendMessage`).

O **AWS Security Token Service (STS)** é o serviço que fica no coração deste processo. Quando uma instância EC2 precisa de permissões, ela contata o serviço de metadados local, que por sua vez chama o STS. O STS valida que o serviço EC2 tem permissão para assumir a role solicitada e, em caso afirmativo, emite **credenciais de segurança temporárias** (uma Access Key, uma Secret Key e um Session Token). Essas credenciais têm um tempo de vida curto (geralmente algumas horas) e são rotacionadas automaticamente, eliminando o risco das credenciais estáticas.

## 2. Arquitetura e Casos de Uso

### Cenário Simples: Uma Aplicação Lendo de um Bucket S3
Uma aplicação simples rodando em uma instância EC2 precisa exibir imagens que estão armazenadas em um bucket S3 privado.

-   **Implementação:**
    1.  Uma IAM Role chamada `WebApp-S3-ReadOnly-Role` é criada.
    2.  A política de confiança da role permite que o serviço EC2 a assuma.
    3.  A política de permissão gerenciada pela AWS `AmazonS3ReadOnlyAccess` é anexada à role.
    4.  A instância EC2 é lançada com esta IAM Role anexada (através de um Instance Profile).
-   **Justificativa:** A aplicação, usando o SDK da AWS, obterá automaticamente as credenciais temporárias e poderá ler as imagens do S3. Nenhuma chave de acesso é armazenada na instância. Se a instância for comprometida, o invasor só poderá ler do S3, e apenas por um tempo limitado até que as credenciais expirem. Ele não poderá deletar nada ou acessar outros serviços.

### Cenário Corporativo Robusto: Acesso Granular a Múltiplos Serviços
Um microsserviço de processamento de vídeo, rodando em um cluster de EC2, precisa realizar um fluxo de trabalho complexo:
1.  Ler um vídeo de um bucket S3 de entrada.
2.  Enviar uma mensagem para uma fila SQS para notificar sobre o início do processamento.
3.  Processar o vídeo.
4.  Gravar o vídeo processado em um bucket S3 de saída.
5.  Gravar metadados sobre o processamento em uma tabela do DynamoDB.

-   **Implementação:** Uma única e altamente específica IAM Role é criada para este serviço, `VideoProcessing-Service-Role`.
    -   **Política de Confiança:** Permite que o serviço EC2 a assuma.
    -   **Política de Permissão:** Uma política **customizada e inline** é criada, seguindo o Princípio do Menor Privilégio:
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
-   **Justificativa:** Esta política concede **exatamente** as permissões necessárias, e nada mais. A role não pode deletar objetos, ler de outros buckets ou acessar qualquer outro serviço. Se uma instância neste cluster for comprometida, o raio de explosão é extremamente limitado. Esta abordagem granular é a base da segurança no nível da aplicação na AWS.

## 3. Melhores Práticas (AWS Well-Architected)

-   **Segurança:** **SEMPRE** use IAM Roles para conceder permissões a instâncias EC2. **NUNCA** armazene credenciais estáticas em uma instância.
-   **Segurança:** Siga o Princípio do Menor Privilégio. Crie políticas customizadas que concedem apenas as permissões necessárias para a tarefa em questão. Evite usar políticas gerenciadas pela AWS (como `AdministratorAccess` ou `PowerUserAccess`) em roles para suas aplicações.
-   **Excelência Operacional:** Dê nomes claros e descritivos às suas roles para que sua finalidade seja óbvia (ex: `EC2-Role-For-WebApp-S3-Access`).
-   **Otimização de Custos:** O IAM é um serviço gratuito. Investir tempo na criação de roles seguras não tem custo monetário, mas o retorno em segurança é imenso.

## 4. Guia Prático (Laboratório)

O laboratório é projetado para demonstrar a facilidade e a segurança do uso de IAM Roles em contraste com o anti-padrão de credenciais estáticas.
1.  **Criar a Role:** O aluno cria uma `EC2-S3-ReadOnly-Role` com a política de confiança para o EC2 e a política de permissão `AmazonS3ReadOnlyAccess`.
2.  **Anexar a Role:** O aluno anexa esta role a uma instância EC2 existente.
3.  **Validar:** O aluno faz SSH na instância e executa `aws s3 ls`. O comando funciona sem qualquer configuração de credenciais.
4.  **Analisar:** O aluno é instruído a verificar a ausência do arquivo `~/.aws/credentials` para provar que nenhuma chave estática foi usada. Em seguida, ele pode usar o serviço de metadados (`curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ROLE_NAME`) para ver as credenciais temporárias que o SDK usa nos bastidores. Este passo desmistifica o processo e revela a "mágica" segura que acontece.
