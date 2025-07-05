# Módulo 2.3: Criptografia em Trânsito na VPC

**Tempo de Aula:** 30 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento básico de HTTP/HTTPS e portas de rede.
*   Familiaridade com o conceito de Application Load Balancer (ALB).
*   Noções básicas de DNS e gerenciamento de domínios.

## Objetivos

*   Entender os fundamentos da criptografia de chave pública (assimétrica) e o papel do TLS/SSL.
*   Analisar o processo de handshake TLS para o estabelecimento de uma sessão segura.
*   Implementar a terminação TLS (SSL Offloading) em um Application Load Balancer usando um certificado do ACM.
*   Forçar o uso de conexões seguras através de redirecionamento HTTP para HTTPS.
*   Discutir a importância da criptografia em trânsito para a segurança e conformidade de aplicações.

---

## 1. A Mecânica da Criptografia em Trânsito (Teoria - 30 min)

**Criptografia em trânsito** é o processo de proteger os dados enquanto eles se movem através de uma rede. O objetivo é garantir a **Confidencialidade** (os dados não podem ser lidos se interceptados), a **Integridade** (os dados não podem ser alterados sem detecção) e a **Autenticação** (podemos ter certeza de com quem estamos falando). O protocolo padrão para isso na web é o **TLS (Transport Layer Security)**, o sucessor do SSL.

### Criptografia de Chave Pública (Assimétrica)

O TLS é construído sobre o conceito de criptografia de chave pública. Cada participante tem um par de chaves matematicamente relacionadas:

*   **Chave Pública:** Pode ser distribuída livremente para qualquer pessoa. É usada para **criptografar** dados.
*   **Chave Privada:** Deve ser mantida em segredo absoluto pelo proprietário. É a única chave que pode **descriptografar** os dados que foram criptografados com a chave pública correspondente.

Isso resolve o problema da troca de chaves: como duas partes que nunca se encontraram podem concordar em uma chave secreta para conversar? A resposta está no **handshake TLS**.

### O Handshake TLS (Visão Simplificada)

1.  **ClientHello:** O seu navegador (cliente) envia uma mensagem para o servidor dizendo: "Olá, quero iniciar uma sessão segura. Eu suporto estes algoritmos de criptografia e versões de TLS."
2.  **ServerHello & Certificate:** O servidor responde: "Olá. Vamos usar este algoritmo e esta versão de TLS. E aqui está o meu **certificado digital** para provar quem eu sou e minha chave pública."
    *   O **certificado digital** é um documento digital emitido por uma **Autoridade Certificadora (CA)** confiável (ex: Let's Encrypt, DigiCert, AWS Certificate Manager). O navegador já confia em uma lista de CAs raiz.
    *   O certificado contém informações sobre o proprietário do site (ex: `www.amazon.com`) e, mais importante, a **chave pública** do servidor.
3.  **Verificação do Cliente:** O navegador verifica a assinatura digital do certificado para garantir que ele é autêntico, não foi adulterado e foi emitido por uma CA confiável para aquele domínio específico. Se tudo estiver correto, o navegador agora confia na chave pública do servidor.
4.  **Troca de Chave de Sessão:** A criptografia de chave pública é computacionalmente intensiva. Para a comunicação real, usa-se a criptografia simétrica (onde a mesma chave criptografa e descriptografa), que é muito mais rápida. O cliente agora gera uma **chave de sessão** aleatória. Ele a **criptografa usando a chave pública do servidor** e a envia de volta.
5.  **Início da Sessão Segura:** Apenas o servidor, com sua **chave privada** correspondente, pode descriptografar esta mensagem e obter a chave de sessão. Agora, tanto o cliente quanto o servidor compartilham a mesma chave de sessão secreta, e toda a comunicação subsequente é criptografada com ela.

### SSL Offloading (Terminação TLS) com o ALB

Realizar o handshake TLS e a criptografia/descriptografia contínua consome recursos de CPU. Uma arquitetura de rede eficiente delega essa tarefa a um dispositivo de borda especializado. Na AWS, esse dispositivo é o **Application Load Balancer (ALB)**. Este processo é chamado de **SSL Offloading** ou **Terminação TLS**.

*   **Como Funciona:**
    1.  Você instala o certificado SSL/TLS e a chave privada no **listener** do seu ALB.
    2.  O handshake TLS ocorre entre o cliente e o **ALB**. O ALB descriptografa o tráfego.
    3.  O ALB então encaminha o tráfego **não criptografado** (HTTP, porta 80) ou **recriptografado** (HTTPS, porta 443) para as instâncias de back-end na sua rede privada. A escolha entre HTTP e HTTPS para o back-end depende dos requisitos de segurança e conformidade.

*   **Vantagens:**
    *   **Gerenciamento Centralizado:** Gerencie certificados em um único lugar (ACM).
    *   **Performance:** Libera as instâncias de back-end para se concentrarem na lógica da aplicação, melhorando a performance geral.
    *   **Roteamento Inteligente:** Permite que o ALB inspecione o tráfego da Camada 7 (cabeçalhos HTTP, etc.) para tomar decisões de roteamento avançadas.
    *   **Segurança Aprimorada:** O ALB pode aplicar políticas de segurança TLS (SSL Policies) para garantir que apenas versões e cifras seguras de TLS sejam usadas.

---

## 2. Configuração de Certificados SSL (Prática - 60 min)

Neste laboratório, vamos proteger nosso `Lab-ALB` adicionando um listener HTTPS, usando um certificado gratuito do AWS Certificate Manager (ACM), e forçando todo o tráfego a usar a conexão segura. Isso é uma prática padrão para qualquer aplicação web moderna.

### Cenário: Protegendo um Site de E-commerce

Uma empresa de e-commerce precisa garantir que todas as comunicações com seus clientes sejam criptografadas para proteger dados sensíveis (informações de login, dados de cartão de crédito) e para construir confiança. Eles usarão um ALB para distribuir o tráfego para seus servidores web e precisam configurar o HTTPS com um certificado gerenciado pela AWS.

### Roteiro Prático

**Passo 1: Solicitar um Certificado Público no ACM**
*Nota: Para concluir este passo, você precisa ter acesso a um nome de domínio registrado e configurado no Route 53 ou em outro provedor de DNS.*

1.  Navegue até o **AWS Certificate Manager (ACM)** na mesma região do seu ALB.
2.  Clique em **"Request a certificate"** > **"Request a public certificate"**.
3.  **Domain name:** Insira o nome de domínio para o qual você emitirá o certificado (ex: `app.seusite.com` ou `*.seusite.com` para um certificado curinga).
4.  **Validation method:** Escolha **"DNS validation"**. É o método recomendado, pois o ACM pode renovar automaticamente os certificados validados por DNS, sem intervenção manual.
5.  Clique em **"Request"**. O ACM fornecerá um registro CNAME que você deve criar na sua zona de DNS (no Route 53 ou em seu provedor de DNS) para provar que você controla o domínio.
6.  Crie o registro CNAME e aguarde o status do certificado mudar de "Pending validation" para **"Issued"**. Isso pode levar alguns minutos.

**Passo 2: Adicionar um Listener HTTPS ao ALB**
1.  Navegue até o console do **EC2** > **Load Balancers**.
2.  Selecione o seu `Lab-ALB` (criado no Módulo 1.2) e vá para a aba **"Listeners"**.
3.  Clique em **"Add listener"**.
4.  **Protocol:** `HTTPS`, **Port:** `443`.
5.  **Default action:** Encaminhar (`Forward to`) para o seu Target Group (`Lab-App-TG`).
6.  **Secure listener settings > Default SSL/TLS certificate:**
    *   Selecione **"From ACM"** e escolha o certificado que você acabou de emitir.
7.  Clique em **"Add"**.

**Passo 3: Forçar Segurança (Redirecionar HTTP para HTTPS)**
É uma má prática permitir que os usuários acessem seu site por HTTP não seguro. Vamos configurar o ALB para redirecionar automaticamente todo o tráfego HTTP para HTTPS.

1.  Na aba **"Listeners"**, selecione o listener da **Porta 80 (HTTP)** e clique em **"Edit"**.
2.  Remova a ação de encaminhamento (`forward`) existente.
3.  Clique em **"Add action"** e selecione **"Redirect to"**.
4.  Configure o redirecionamento:
    *   **Protocol:** `HTTPS`
    *   **Port:** `443`
    *   **Response code:** `HTTP_301` (redirecionamento permanente - recomendado para SEO e para que os navegadores cacheiem o redirecionamento).
5.  Salve as alterações.

**Passo 4: Atualizar o Security Group e Testar**
1.  Certifique-se de que o Security Group do seu ALB (`ALB-SG`) permite tráfego de entrada na **porta 443** de `0.0.0.0/0`. (Se você já configurou o SG do ALB no Módulo 1.2 para 443, este passo pode ser ignorado).
2.  **Configurar DNS:** Crie um registro `CNAME` ou `A (Alias)` no seu provedor de DNS que aponte o nome de domínio do seu certificado (ex: `app.seusite.com`) para o **nome DNS do seu ALB**.
3.  Aguarde a propagação do DNS (pode levar alguns minutos).
4.  **Teste 1 (Redirecionamento):**
    *   Abra seu navegador e tente acessar `http://app.seusite.com`.
    *   **Resultado esperado:** O navegador deve ser automaticamente redirecionado para `https://app.seusite.com`.
5.  **Teste 2 (Conexão Segura):**
    *   Acesse `https://app.seusite.com`.
    *   **Resultado esperado:** O site deve carregar, e você deve ver um ícone de cadeado na barra de endereço, indicando que o handshake TLS foi bem-sucedido e a conexão é segura.

Você implementou com sucesso a terminação TLS, garantindo que todo o tráfego entre seus clientes e sua aplicação seja criptografado, seguindo as melhores práticas de segurança na nuvem.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Sempre use ACM para Certificados Públicos:** O AWS Certificate Manager (ACM) oferece certificados SSL/TLS gratuitos e gerenciados para uso com serviços AWS integrados (ALB, CloudFront, API Gateway). Ele também lida com a renovação automática, simplificando a gestão.
*   **Validação DNS:** Prefira a validação DNS para certificados ACM, pois permite a renovação automática.
*   **Terminação TLS no Borda:** Termine o TLS no ALB (ou CloudFront) para descarregar a carga de criptografia das suas instâncias de back-end e centralizar o gerenciamento de certificados.
*   **Criptografia End-to-End (Opcional):** Para requisitos de segurança mais rigorosos, você pode configurar o ALB para recriptografar o tráfego para as instâncias de back-end (HTTPS para o Target Group). Isso é conhecido como criptografia ponta a ponta.
*   **Políticas de Segurança TLS:** O ALB permite que você escolha políticas de segurança TLS que definem as versões de TLS e as cifras que o balanceador de carga usa para negociar conexões com os clientes. Sempre use as políticas mais recentes e seguras recomendadas pela AWS.
*   **HSTS (HTTP Strict Transport Security):** Considere habilitar o HSTS no seu servidor web ou no CloudFront para forçar os navegadores a sempre usarem HTTPS para seu domínio, mesmo que o usuário digite HTTP.
*   **Monitoramento de Certificados:** Monitore a expiração de certificados (se não estiver usando ACM) e a saúde dos listeners do ALB no CloudWatch.
