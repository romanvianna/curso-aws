# Módulo 1.2: Expondo a Rede Privada de Forma Segura

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Pré-requisitos

*   Conhecimento de sub-redes públicas e privadas em uma VPC.
*   Familiaridade com Security Groups e Network ACLs.
*   Noções básicas de HTTP/HTTPS e portas de rede.

## Objetivos

*   Entender os conceitos de Load Balancing e Proxy Reverso como padrões de arquitetura para expor serviços.
*   Diferenciar entre balanceamento de carga de Camada 4 (Rede) e Camada 7 (Aplicação).
*   Posicionar o Application Load Balancer (ALB) como um proxy reverso de Camada 7 gerenciado.
*   Implementar um ALB para distribuir tráfego de forma segura para instâncias em sub-redes privadas.
*   Discutir casos de uso e cenários de arquitetura comuns em empresas.

---

## 1. Padrões de Arquitetura para Exposição de Serviços (Teoria - 45 min)

Já estabelecemos que nossos servidores de aplicação e bancos de dados devem residir em sub-redes privadas, isolados da internet. No entanto, os usuários precisam usar nossa aplicação. Como expomos os serviços que rodam nesses servidores privados de forma segura, escalável e resiliente? A resposta está em dois padrões de arquitetura interligados: **Proxy Reverso** e **Load Balancing**.

### O Padrão do Proxy Reverso

Um **proxy reverso** é um servidor que se posiciona na frente de um ou mais servidores de back-end (ex: servidores web, de aplicação). Ele atua como o intermediário para todas as requisições dos clientes destinadas a esses servidores.

*   **Como Funciona:**
    1.  O cliente se conecta ao proxy reverso, pensando que está se conectando ao servidor da aplicação real.
    2.  O proxy reverso recebe a requisição e a encaminha para um dos servidores de back-end que ele gerencia.
    3.  O servidor de back-end processa a requisição e envia a resposta de volta para o proxy reverso.
    4.  O proxy reverso, por sua vez, entrega a resposta ao cliente.

*   **Benefícios Chave:**
    *   **Segurança e Abstração:** O proxy reverso oculta a existência e as características dos servidores de back-end. O cliente nunca interage diretamente com eles, o que reduz drasticamente a superfície de ataque.
    *   **Ponto Central de Controle:** Como todo o tráfego passa pelo proxy, ele pode realizar funções centralizadas, como:
        *   **Terminação SSL/TLS:** Descriptografar o tráfego HTTPS, aliviando os servidores de back-end.
        *   **Cache:** Armazenar conteúdo estático para acelerar a entrega.
        *   **Compressão:** Comprimir respostas para economizar largura de banda.
        *   **Balanceamento de Carga:** Distribuir as requisições entre múltiplos servidores de back-end.

### Balanceamento de Carga: Camada 4 vs. Camada 7

O balanceamento de carga é uma das funções mais importantes de um proxy reverso. Ele distribui o tráfego para evitar que um único servidor fique sobrecarregado e para garantir alta disponibilidade. Existem dois tipos principais, baseados nas camadas do Modelo OSI:

1.  **Balanceamento de Carga de Camada 4 (Transporte):**
    *   **Como Funciona:** Toma decisões de roteamento com base em informações da Camada 4, como o endereço IP e a porta de destino. Ele não inspeciona o conteúdo do pacote. Ele simplesmente encaminha os pacotes TCP/UDP para um servidor de back-end com base em um algoritmo (ex: Round Robin).
    *   **Vantagens:** Extremamente rápido e eficiente, pois o processamento é mínimo.
    *   **Exemplo na AWS:** **Network Load Balancer (NLB)**. Ideal para aplicações de altíssima performance e baixa latência que lidam com tráfego TCP/UDP.

2.  **Balanceamento de Carga de Camada 7 (Aplicação):**
    *   **Como Funciona:** Este é um balanceador muito mais inteligente. Ele opera na camada de aplicação e pode inspecionar o conteúdo da requisição, como cabeçalhos HTTP, cookies, e o caminho da URL.
    *   **Roteamento Avançado:** Ele pode tomar decisões de roteamento complexas. Por exemplo:
        *   Requisições para `meusite.com/api/*` vão para o grupo de servidores de API.
        *   Requisições para `meusite.com/imagens/*` vão para o grupo de servidores de imagem.
        *   Requisições com um cabeçalho `User-Agent` de celular vão para a versão móvel do site.
    *   **Exemplo na AWS:** **Application Load Balancer (ALB)**. É a escolha padrão para a maioria das aplicações web e de microsserviços modernos.

### O ALB como um Proxy Reverso de Camada 7 Gerenciado

O **Application Load Balancer (ALB)** da AWS é a implementação perfeita de um proxy reverso de Camada 7, gerenciado, seguro e escalável. Ao colocar um ALB nas suas sub-redes públicas para encaminhar o tráfego para instâncias nas suas sub-redes privadas, você está implementando o padrão de arquitetura recomendado pela AWS para aplicações web.

---

## 2. Configuração de Application Load Balancer (Prática - 75 min)

Neste laboratório, vamos implementar esta arquitetura padrão. Colocaremos um ALB na frente de duas "instâncias de aplicação" rodando em sub-redes privadas, simulando um ambiente web seguro e de alta disponibilidade.

### Cenário

Neste cenário, uma empresa de e-commerce deseja expor sua aplicação web de forma segura e escalável. A aplicação consiste em servidores web (front-end) e servidores de API (back-end), ambos residindo em sub-redes privadas. O ALB será usado para distribuir o tráfego para os servidores web, que por sua vez se comunicarão com os servidores de API.

### Roteiro Prático

**Passo 1: Preparar a VPC e os Security Groups**
1.  **VPC Multi-AZ:** Certifique-se de que sua `Lab-VPC` tenha sub-redes públicas e privadas em pelo menos duas Zonas de Disponibilidade.
2.  **Security Group do ALB (`ALB-SG`):** Crie um novo SG. Regra de Entrada: `Allow TCP ports 80, 443` from `0.0.0.0/0`.
3.  **Security Group da Aplicação (`App-SG`):** Crie um novo SG. Regra de Entrada: `Allow TCP port 80` (a porta do nosso servidor web de teste) com a **Origem (Source)** sendo o Security Group `ALB-SG`. Isso garante que apenas o ALB possa falar com nossas instâncias.

**Passo 2: Lançar as Instâncias de Aplicação**
1.  Lance duas instâncias EC2 `t2.micro` com Amazon Linux 2.
    *   **Instância 1:** `AppServer-A` na **sub-rede privada** da primeira AZ.
    *   **Instância 2:** `AppServer-B` na **sub-rede privada** da segunda AZ.
2.  Para ambas, associe o Security Group `App-SG`.
3.  Na seção **"User data"**, insira o script abaixo para instalar um servidor web que exibe o ID da instância, permitindo-nos ver o balanceamento de carga em ação.
    ```bash
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "<h1>Request handled by AppServer: $INSTANCE_ID</h1>" > /var/www/html/index.html
    ```

**Passo 3: Criar um Target Group**
O Target Group define para onde o ALB enviará o tráfego.
1.  No console do EC2, vá para **Target Groups** > **Create target group**.
2.  **Target type:** `Instances`.
3.  **Target group name:** `Lab-App-TG`
4.  **Protocol/Port:** `HTTP` / `80`.
5.  **VPC:** `Lab-VPC`.
6.  Clique em **Next**. Na página **"Register targets"**, selecione as duas instâncias (`AppServer-A`, `AppServer-B`) e clique em **"Include as pending below"**.
7.  Clique em **"Create target group"**.

**Passo 4: Criar o Application Load Balancer**
1.  Vá para **Load Balancers** > **Create Load Balancer** > **Application Load Balancer**.
2.  **Load balancer name:** `Lab-ALB`
3.  **Scheme:** `Internet-facing`.
4.  **Network mapping:**
    *   **VPC:** `Lab-VPC`.
    *   **Mappings:** Selecione as **duas sub-redes PÚBLICAS** (uma de cada AZ).
5.  **Security groups:** Remova o SG padrão e selecione o `ALB-SG`.
6.  **Listeners and routing:**
    *   O listener padrão na porta 80 deve encaminhar (`forward to`) para o `Lab-App-TG`.
7.  Clique em **"Create load balancer"**.

**Passo 5: Testar a Solução**
1.  Aguarde o estado do ALB mudar para "active".
2.  Vá para a aba **"Description"** do seu ALB e copie o **DNS name**.
3.  Cole o nome DNS no seu navegador.
4.  **Resultado esperado:** Você verá a mensagem "Request handled by AppServer: i-xxxxxxxx".
5.  **Atualize a página várias vezes.** Você deverá ver o ID da instância mudar, pois o ALB está distribuindo as requisições entre `AppServer-A` e `AppServer-B` (usando o algoritmo Round Robin por padrão).

Você acaba de implementar uma arquitetura web padrão, segura e de alta disponibilidade, onde o ALB atua como um proxy reverso, protegendo e distribuindo a carga para os servidores de aplicação na rede privada.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Sempre use HTTPS:** Configure o ALB para terminar o SSL/TLS (HTTPS) e, se possível, redirecione todo o tráfego HTTP para HTTPS. Isso garante que a comunicação entre o cliente e o ALB seja sempre criptografada.
*   **Security Groups Granulares:** Utilize Security Groups para controlar o fluxo de tráfego entre o ALB e suas instâncias de back-end. O Security Group das instâncias de aplicação deve permitir tráfego apenas do Security Group do ALB, e não de `0.0.0.0/0`.
*   **Monitoramento:** Monitore as métricas do ALB no CloudWatch, como `HealthyHostCount`, `UnHealthyHostCount`, `HTTPCode_Target_5XX_Count` e `TargetConnectionErrorCount`. Configure alarmes para ser notificado sobre problemas de saúde da aplicação ou erros.
*   **Auto Scaling:** Combine o ALB com o Auto Scaling Group para escalar automaticamente suas instâncias de aplicação com base na demanda, garantindo alta disponibilidade e performance.
*   **Zonas de Disponibilidade:** Distribua suas instâncias de aplicação e o ALB por múltiplas Zonas de Disponibilidade para garantir alta disponibilidade e resiliência a falhas de AZ.
*   **Logs de Acesso:** Habilite os logs de acesso do ALB para o S3. Esses logs contêm informações detalhadas sobre as requisições que chegam ao seu balanceador de carga, sendo úteis para análise de tráfego, depuração e auditoria.
