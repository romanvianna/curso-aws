# Módulo 1.3: Configurando a Integração do S3 com a VPC

**Tempo de Aula:** 30 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento básico sobre o Amazon S3 (buckets, objetos).
*   Familiaridade com conceitos de IAM (usuários, roles, políticas).
*   Compreensão de como o NAT Gateway funciona para acesso à internet a partir de sub-redes privadas.

## Objetivos

*   Entender o S3 como um serviço de objeto regional, mas externo à VPC.
*   Aprender sobre o modelo de segurança do S3, focando em políticas de bucket baseadas em recursos.
*   Utilizar condições em políticas de bucket para criar um perímetro de dados, restringindo o acesso a partir de uma VPC específica.
*   Discutir a importância da segurança de dados no S3 e as melhores práticas.

---

## 1. O Modelo de Segurança do S3 e o Perímetro de Rede (Teoria - 30 min)

### S3: Um Serviço Fora da Sua Rede

É fundamental entender que o **Amazon S3** não é um serviço que reside *dentro* da sua VPC. O S3 é um serviço de armazenamento de objetos massivamente escalável que opera em uma infraestrutura própria da AWS, acessível através de **endpoints de API públicos** na internet (ex: `s3.us-east-1.amazonaws.com`).

Isso tem uma implicação de rede importante: quando uma instância EC2 na sua VPC quer se comunicar com o S3, por padrão, o tráfego deve sair da sua VPC e atravessar a internet pública para chegar ao endpoint do S3.

*   **Fluxo Padrão (Sub-rede Privada):**
    `Instância EC2 -> Tabela de Rotas Privada -> NAT Gateway -> Tabela de Rotas Pública -> Internet Gateway -> Endpoint Público do S3`

Este fluxo funciona, mas tem duas desvantagens significativas para ambientes corporativos:
1.  **Custo:** O tráfego que passa por um NAT Gateway incorre em custos de processamento e transferência de dados. Para grandes volumes de dados, isso pode ser caro.
2.  **Segurança/Conformidade:** Embora a conexão com a API do S3 seja criptografada (HTTPS), algumas políticas de segurança corporativa ou de conformidade (como HIPAA, LGPD ou PCI DSS) podem desaprovar ou proibir que o tráfego de dados sensíveis saia do perímetro da rede privada e transite pela internet pública, mesmo que criptografado.

(A solução ideal para o fluxo de tráfego privado para o S3 é o VPC Endpoint, que será abordado no próximo módulo. Por agora, vamos focar em como controlar o acesso no nível do S3, independentemente do caminho de rede).

### O Modelo de Segurança do S3: IAM e Políticas de Bucket

A segurança no S3 é baseada no **IAM (Identity and Access Management)** e funciona em dois níveis principais, que se complementam:

1.  **Políticas Baseadas em Identidade (IAM Policies):** Anexadas a um usuário, grupo ou role do IAM. Elas definem o que *aquela identidade* pode fazer. Ex: "O usuário `dev-ops` pode ler e escrever objetos no `Bucket-Logs-Producao`".

2.  **Políticas Baseadas em Recurso (Bucket Policies):** Anexadas ao próprio recurso (o bucket S3). Elas definem quem pode acessar *aquele bucket específico* e sob quais condições. Ex: "Qualquer pessoa pode ler objetos deste bucket, mas apenas de um IP específico".

Uma requisição é permitida somente se não houver uma negação explícita (`Deny`) em *nenhuma* das políticas (identidade ou recurso) e houver uma permissão (`Allow`) em *pelo menos uma* dessas políticas.

### Criando um Perímetro de Dados com Políticas de Bucket

As políticas de bucket são a ferramenta ideal para criar um **perímetro de dados** em torno do seu bucket. Você pode criar regras que não se baseiam apenas em *quem* está fazendo a requisição, mas também em *de onde* a requisição está vindo. Isso é crucial para garantir que dados sensíveis não sejam acessados de locais não autorizados.

Isso é feito usando o elemento `Condition` na política JSON. A AWS fornece chaves de condição globais que podem ser usadas para verificar o contexto da rede da requisição:

*   `aws:SourceIp`: Verifica o endereço IP público de origem da requisição. Se o tráfego vier de uma instância em uma sub-rede privada via NAT Gateway, este será o **Elastic IP do NAT Gateway**.
*   `aws:SourceVpc`: Verifica o ID da VPC de onde a requisição se origina. (Esta condição só funciona se você estiver usando um VPC Endpoint do tipo Gateway ou Interface, pois, caso contrário, o S3 não tem como saber a VPC de origem).
*   `aws:SourceVpce`: Verifica o ID do VPC Endpoint específico. (Mais granular que `aws:SourceVpc`).

Usando essas condições, podemos criar uma política poderosa que diz: "Nega todo o acesso a este bucket, a menos que a requisição venha de dentro da minha rede corporativa (verificando `aws:SourceIp`) ou de dentro da minha VPC (verificando `aws:SourceVpc` ou `aws:SourceVpce`)".

---

## 2. Integração S3 com VPC (Prática - 60 min)

Neste laboratório, vamos criar um bucket S3 e configurar uma política de bucket que o protege, permitindo o acesso apenas a partir do IP público do nosso NAT Gateway. Isso garante que apenas as instâncias na nossa `Lab-VPC` possam interagir com ele, simulando um cenário onde apenas recursos internos podem acessar um bucket de logs ou backups.

### Cenário: Armazenamento Seguro de Logs de Aplicação

Uma empresa de software armazena logs de suas aplicações em um bucket S3. Por questões de segurança e conformidade, esses logs só podem ser acessados por instâncias EC2 que residem dentro da VPC de produção da empresa. Qualquer tentativa de acesso de fora da VPC (mesmo por um usuário IAM autorizado) deve ser negada. Usaremos o Elastic IP do NAT Gateway como o ponto de origem confiável para o tráfego de saída da VPC.

### Roteiro Prático

**Passo 1: Criar um Bucket S3 e Obter o IP do NAT GW**
1.  Navegue até o console do **S3** e crie um novo bucket com um nome único globalmente (ex: `lab-vpc-logs-seu-nome-12345`). Mantenha a opção **"Block all public access"** habilitada (é a melhor prática).
2.  Navegue até o console da **VPC** e vá para **NAT Gateways**. Selecione seu `Lab-NAT-GW` (criado no Módulo 1.1) e copie seu **Elastic IP address**.

**Passo 2: Preparar a Instância e a IAM Role**
1.  Certifique-se de que você tem uma instância em sua sub-rede privada (`Lab-DBServer` ou uma nova instância de aplicação) com acesso à internet via NAT Gateway.
2.  Certifique-se de que a instância tem uma **IAM Role** anexada com permissões para o S3 (ex: a política gerenciada `AmazonS3FullAccess` para este laboratório, ou uma política mais granular como `s3:PutObject` e `s3:GetObject` para o bucket específico).

**Passo 3: Criar e Aplicar a Política de Bucket**
1.  Navegue de volta para o seu bucket S3 e vá para a aba **"Permissions"**.
2.  Na seção **"Bucket policy"**, clique em **"Edit"**.
3.  Cole a seguinte política JSON. **Lembre-se de substituir `YOUR_BUCKET_NAME` e `YOUR_NAT_GATEWAY_EIP`**.
    ```json
    {
        "Version": "2012-10-17",
        "Id": "PolicyForNATIP",
        "Statement": [
            {
                "Sid": "DenyAccessUnlessFromNAT",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:*",
                "Resource": [
                    "arn:aws:s3:::YOUR_BUCKET_NAME",
                    "arn:aws:s3:::YOUR_BUCKET_NAME/*"
                ],
                "Condition": {
                    "NotIpAddress": {
                        "aws:SourceIp": "YOUR_NAT_GATEWAY_EIP/32"
                    }
                }
            }
        ]
    }
    ```
    *   **Analisando a Política:** Esta política é uma **negação explícita com uma exceção**. Ela diz: "**NEGA** (`Deny`) todas as ações do S3 (`s3:*`) para todos os principais (`*`) neste bucket, **A MENOS QUE** (`Condition`: `NotIpAddress`) o IP de origem da requisição **SEJA** o IP do nosso NAT Gateway". Isso significa que apenas requisições originadas do NAT Gateway (ou seja, de dentro da sua VPC via NAT) serão permitidas. Qualquer outra origem será negada.
4.  Clique em **"Save changes"**.

**Passo 4: Testar o Acesso**
1.  **Conecte-se à sua instância de teste** na sub-rede privada (usando seu bastion host, se configurado).
2.  Uma vez na instância, crie um arquivo de teste: `echo "log de aplicacao de teste" > app-log.txt`
3.  **Tente copiar o arquivo para o S3:**
    ```bash
    aws s3 cp app-log.txt s3://YOUR_BUCKET_NAME/app-log.txt
    ```
4.  **Resultado esperado:** Sucesso! O upload deve ser concluído. O tráfego saiu pelo NAT Gateway, então a requisição chegou ao S3 com o IP de origem correto, satisfazendo a condição da política.

5.  **Teste de Falha (Opcional):**
    *   Execute o mesmo comando `aws s3 cp` da sua **máquina local** (que tem um IP público diferente do NAT Gateway).
    *   A operação falhará com um erro de **"Access Denied"**. Seu IP não corresponde ao IP do NAT Gateway, então a política de negação foi aplicada.

Este laboratório demonstra como as políticas de bucket, combinadas com condições de rede, podem ser usadas para criar um perímetro de dados robusto, garantindo que seus dados no S3 só possam ser acessados a partir da sua rede VPC aprovada.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Princípio do Menor Privilégio:** Sempre aplique o princípio do menor privilégio ao configurar permissões no S3. Conceda apenas as permissões necessárias para a tarefa específica.
*   **Bloqueio de Acesso Público:** Mantenha o "Block all public access" habilitado para seus buckets S3, a menos que haja uma necessidade de negócio muito específica e justificada para acesso público.
*   **Criptografia:** Habilite a criptografia em repouso para todos os objetos no S3 (SSE-S3, SSE-KMS ou SSE-C). A criptografia em trânsito (HTTPS) já é padrão para o acesso à API do S3.
*   **Versionamento:** Habilite o versionamento para proteger seus objetos contra exclusões acidentais ou maliciosas e para manter um histórico de alterações.
*   **MFA Delete:** Para buckets críticos, considere habilitar o MFA Delete, que exige autenticação multifator para excluir objetos ou desabilitar o versionamento.
*   **VPC Endpoints para S3:** Para tráfego S3 de dentro da VPC, a melhor prática é usar um VPC Endpoint do tipo Gateway. Isso garante que o tráfego permaneça na rede da AWS, sem passar pelo NAT Gateway, o que melhora a segurança, reduz a latência e elimina custos de processamento de dados do NAT Gateway. Este será o foco do próximo módulo.
*   **Monitoramento:** Monitore o acesso aos seus buckets S3 usando S3 Access Logs e CloudTrail para auditoria e detecção de atividades suspeitas.
