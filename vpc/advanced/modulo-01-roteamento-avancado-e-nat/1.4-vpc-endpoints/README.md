# Módulo 1.4: VPC Endpoints

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Objetivos

- Entender o conceito de acesso privado a serviços públicos dentro de uma rede de nuvem.
- Aprofundar a diferença entre os mecanismos de implementação de endpoints: Roteamento (Gateway) vs. Interface de Rede (Interface).
- Criar e configurar um Gateway Endpoint para S3, analisando o impacto na tabela de rotas.
- Criar e configurar um Interface Endpoint, analisando o impacto no DNS e na segurança.

---

## 1. Trazendo os Serviços da AWS para Dentro da sua Rede (Teoria - 45 min)

Já vimos que o acesso padrão a serviços da AWS (como S3, SQS, etc.) a partir de uma VPC privada requer que o tráfego saia para a internet via NAT Gateway. **VPC Endpoints** são a tecnologia que muda fundamentalmente esse paradigma. Eles permitem que você se conecte a serviços da AWS como se eles estivessem dentro da sua VPC, mantendo todo o tráfego na rede global e segura da Amazon, sem nunca tocar na internet pública.

### O Conceito de Acesso Privado

Imagine que a rede global da Amazon é uma vasta rede de rodovias privadas e de alta velocidade. Sua VPC é sua propriedade privada com uma saída para essas rodovias. Os serviços da AWS, como o S3, são grandes cidades ao longo dessas rodovias. 

-   **Sem Endpoints:** Para ir da sua propriedade (VPC) para a cidade do S3, você primeiro pega uma estrada local até a rodovia pública (internet) e depois entra na cidade do S3 pela entrada principal pública. 
-   **Com Endpoints:** Um VPC Endpoint constrói uma **rampa de acesso privada e direta** da sua propriedade (VPC) para a rodovia privada da Amazon, que leva diretamente à cidade do S3, sem nunca usar a rodovia pública.

Isso resulta em maior segurança, menor latência e, em muitos casos, menor custo (pois você evita os custos de processamento do NAT Gateway).

Existem duas maneiras de construir essa "rampa de acesso":

### 1. Gateway Endpoints (Acesso via Roteamento)

-   **Serviços Suportados:** Apenas **Amazon S3** e **DynamoDB** (os primeiros serviços massivos da AWS).
-   **Mecanismo:** Esta abordagem modifica o **mapa (a tabela de rotas)** da sua VPC.
    1.  Você cria um Gateway Endpoint e o associa a uma ou mais tabelas de rotas (geralmente das suas sub-redes privadas).
    2.  O endpoint adiciona automaticamente **rotas altamente específicas** para os intervalos de IP públicos do serviço (S3 ou DynamoDB) à sua tabela de rotas. O alvo (`target`) dessas rotas é o próprio endpoint (ex: `vpce-xxxxxxxx`).
    3.  Quando uma instância tenta acessar o S3, o roteador da VPC aplica a regra de **"longest prefix match"**. A rota para o S3 criada pelo endpoint é muito mais específica do que a rota padrão `0.0.0.0/0` para o NAT Gateway. Portanto, o tráfego para o S3 é direcionado para o endpoint, enquanto todo o outro tráfego de internet continua indo para o NAT Gateway.
-   **Características:**
    -   **Gratuito:** Não há custo para o endpoint em si.
    -   **Não é um Recurso de Rede:** Ele não existe "dentro" da sua sub-rede; não tem ENI nem endereço IP. É puramente uma construção de roteamento.

### 2. Interface Endpoints (AWS PrivateLink)

-   **Serviços Suportados:** A grande maioria dos outros serviços da AWS (EC2 API, SQS, Kinesis, etc.), serviços de parceiros e seus próprios serviços privados.
-   **Mecanismo:** Esta abordagem coloca um **representante do serviço** dentro da sua rede.
    1.  Você cria um Interface Endpoint e especifica em quais sub-redes (uma por AZ para alta disponibilidade) ele deve residir.
    2.  O endpoint provisiona uma **Interface de Rede Elástica (ENI)** em cada sub-rede especificada. Cada ENI recebe um **endereço IP privado** do bloco CIDR daquela sub-rede.
    3.  **Mágica do DNS:** A AWS cria nomes de DNS privados para o endpoint. Quando a opção de DNS privado está habilitada, o resolvedor de DNS da VPC é sobrecarregado. Quando sua aplicação tenta resolver o nome de DNS público padrão do serviço (ex: `sqs.us-east-1.amazonaws.com`), o DNS da VPC intercepta a consulta e a resolve para os **endereços IP privados** das ENIs do endpoint.
    4.  Sua aplicação se conecta a um IP privado dentro da sua própria VPC, e o PrivateLink encaminha esse tráfego para o serviço de forma transparente.
-   **Características:**
    -   **Custo:** Interface Endpoints têm um custo por hora por ENI, mais uma taxa de processamento de dados.
    -   **Recurso de Rede:** É um recurso real na sua sub-rede. Você pode associar **Security Groups** a ele para controlar qual tráfego pode chegar ao endpoint.
    -   **Acesso On-Premises:** Como o endpoint tem um IP privado, ele pode ser acessado de redes on-premises conectadas via VPN ou Direct Connect.

---

## 2. Configuração de Endpoints (Prática - 75 min)

Neste laboratório, vamos criar um Gateway Endpoint para o S3 para otimizar o acesso a partir da nossa sub-rede privada, eliminando a necessidade de passar pelo NAT Gateway e aumentando a segurança.

### Cenário

Atualmente, nossa instância `Lab-DBServer` na sub-rede privada acessa o S3 através do `Lab-NAT-GW`. Vamos criar um Gateway Endpoint para que esse tráfego passe a fluir pela rede privada da AWS, tornando-o mais rápido, barato e seguro.

### Roteiro Prático

**Passo 1: Criar o Gateway Endpoint para o S3**
1.  Navegue até o console da **VPC** > **Endpoints** > **Create endpoint**.
2.  **Name tag:** `s3-gateway-endpoint`
3.  **Service category:** `AWS services`.
4.  **Services:** Na busca, digite `s3` e selecione o serviço que tem o **Type** `Gateway`. O nome será `com.amazonaws.us-east-1.s3`.
5.  **VPC:** Selecione sua `Lab-VPC`.
6.  **Route tables:** **Selecione a tabela de rotas da sua sub-rede PRIVADA** (`Lab-RT-Private`). Este é o passo mais importante. Estamos instruindo o endpoint a modificar este "mapa".
7.  **Policy:** Deixe como `Full Access`. (Aqui você poderia restringir o acesso, por exemplo, permitindo `s3:GetObject` apenas para um bucket específico através deste endpoint).
8.  Clique em **"Create endpoint"**.

**Passo 2: Analisar a Mudança na Tabela de Rotas**
1.  Assim que o endpoint for criado, navegue até **Route Tables**.
2.  Selecione a `Lab-RT-Private`.
3.  Vá para a aba **"Routes"**.
4.  **O que mudou?** Você verá uma nova rota. O destino (`Destination`) não é um CIDR, mas sim um **ID de lista de prefixos (pl-xxxxxxxx)**. Este é um objeto gerenciado pela AWS que contém todos os intervalos de IP públicos para o serviço S3 naquela região. O alvo (`Target`) é o ID do seu VPC Endpoint (`vpce-xxxxxxxx`).

**Analisando a Lógica de Roteamento (Longest Prefix Match):**
-   Quando a instância tenta acessar o S3, o roteador da VPC compara o IP de destino com as rotas.
-   A rota para o S3 (via endpoint) é **mais específica** do que a rota padrão `0.0.0.0/0` para o NAT Gateway.
-   Portanto, o tráfego para o S3 será enviado para o Gateway Endpoint, e todo o *outro* tráfego de internet (ex: `yum update`) continuará indo para o NAT Gateway.

**Passo 3: Validar a Conectividade e a Segurança**
1.  Conecte-se à sua instância na sub-rede privada (`Lab-DBServer`).
2.  Execute um comando para interagir com o S3:
    `aws s3 ls`
3.  **Resultado esperado:** Sucesso. A funcionalidade continua a mesma.

4.  **Teste de Segurança:**
    -   Vá para a sua `Lab-RT-Private` e **remova a rota `0.0.0.0/0` para o NAT Gateway**.
    -   Agora, sua sub-rede privada não tem mais nenhum acesso à internet.
    -   Volte para a instância e tente acessar a internet: `curl -I https://www.google.com`. **Isso falhará.**
    -   Agora, tente acessar o S3 novamente: `aws s3 ls`. **Isso FUNCIONARÁ!**

5.  **Conclusão do Teste:** Este teste prova que o tráfego para o S3 não está mais usando o caminho da internet (via NAT Gateway), mas sim o caminho privado e direto através do VPC Endpoint. Você pode ter acesso ao S3 a partir de uma sub-rede completamente isolada.

**Passo 4 (Discussão): Criando um Interface Endpoint**
-   Discuta como criar um endpoint para o **EC2 API** (`com.amazonaws.us-east-1.ec2`).
-   O processo envolveria:
    1.  Selecionar o serviço `ec2` do tipo `Interface`.
    2.  Selecionar as **sub-redes privadas** onde as ENIs do endpoint seriam criadas.
    3.  Criar e associar um **Security Group** ao endpoint que permita tráfego de entrada na porta 443 (HTTPS) a partir das suas instâncias.
    4.  Após a criação, qualquer chamada `aws ec2 describe-instances` de dentro da VPC seria resolvida para o IP privado do endpoint, mantendo o tráfego de gerenciamento dentro da VPC.

Este módulo conclui o roteamento avançado, mostrando como os VPC Endpoints são a peça final para criar uma rede verdadeiramente privada e otimizada na AWS.