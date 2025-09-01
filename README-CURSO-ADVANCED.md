
# Plano de Curso - AWS VPC: Do Essencial ao Avançado (8 Aulas)

Este documento detalha um plano de estudos intensivo de 8 aulas, com 3 horas de duração cada, projetado para levar os alunos desde os fundamentos essenciais da Amazon VPC até tópicos avançados de rede, segurança e automação.

A primeira aula é um nivelamento crucial, cobrindo todo o conteúdo do curso "VPC Essential" para garantir que todos os alunos tenham a base necessária para as 7 aulas seguintes, que se aprofundarão no conteúdo "VPC Advanced".

---

## Aula 1: Nivelamento - Dominando o Essencial da VPC (3 Horas)

Esta aula intensiva é projetada para revisar e solidificar os conceitos fundamentais da VPC, garantindo uma base sólida para os tópicos avançados.

### Bloco 1: Fundamentos da Rede Virtual (60 min)
- **Tópicos Abordados:**
    - **O que é uma VPC?** (Software-Defined Networking, Isolamento Lógico)
    - **VPC Padrão vs. Customizada:** Casos de uso e por que usar customizadas em produção.
    - **Componentes Chave:** CIDR, Sub-redes, Tabelas de Rotas, Internet Gateway.
    - **Planejamento de Endereçamento IP:** A importância de escolher o bloco CIDR correto para evitar sobreposições futuras.
- **Introdução:**
    A VPC é o seu data center virtual na AWS. Entender como projetá-la corretamente desde o início é a habilidade mais fundamental em redes na nuvem. Discutiremos como a VPC virtualiza conceitos de rede tradicionais e por que a segmentação em sub-redes públicas e privadas é a base da segurança na nuvem.
- **Fontes de Estudo:**
    - **AWS Docs:** [O que é Amazon VPC?](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
    - **AWS Docs:** [VPCs e Sub-redes](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html)
    - **Artigo:** [Noções básicas sobre endereçamento IP e sub-redes para a AWS](https://aws.amazon.com/pt/compare/the-difference-between-ip-address-and-subnet/)
    - **Conceito de Rede:** [RFC 1918 - Address Allocation for Private Internets](https://tools.ietf.org/html/rfc1918)

### Bloco 2: Segurança Básica - Firewalls da VPC (60 min)
- **Tópicos Abordados:**
    - **Security Groups (SGs):** Firewall Stateful em nível de instância. Lógica de "Allow List" e o poder das referências de grupo para microssegmentação.
    - **Network ACLs (NACLs):** Firewall Stateless em nível de sub-rede. Regras numeradas, `Allow`/`Deny` e casos de uso para blacklisting.
    - **Defesa em Profundidade:** Como SGs e NACLs trabalham juntos como camadas de segurança.
- **Introdução:**
    A segurança da VPC é implementada em camadas. Os Security Groups atuam como o segurança pessoal de cada instância, enquanto as Network ACLs são os guardas de fronteira da sub-rede. Dominar a diferença entre stateful (SG) e stateless (NACL) é crucial para configurar a segurança corretamente e para o troubleshooting de conectividade.
- **Fontes de Estudo:**
    - **AWS Docs:** [Controlar o tráfego para recursos usando security groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
    - **AWS Docs:** [Controlar o tráfego para sub-redes usando ACLs de rede](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
    - **Vídeo:** [Security Groups vs. Network ACLs na AWS](https://www.youtube.com/watch?v=r2QkMMi3c0s)
    - **Conceito de Rede:** [Stateful vs. Stateless Firewalls](https://www.cloudflare.com/learning/network-layer/stateful-vs-stateless-firewalls/)

### Bloco 3: Conectividade e Roteamento (60 min)
- **Tópicos Abordados:**
    - **Tabelas de Rotas:** A lógica do "Longest Prefix Match". A Tabela de Rotas Principal vs. Customizadas.
    - **Internet Gateway (IGW):** A porta de entrada e saída para a internet e seu papel no NAT 1:1.
    - **NAT Gateway:** O que é PAT (Port Address Translation) e como o NAT Gateway fornece acesso de saída seguro para sub-redes privadas.
    - **IAM Roles para EC2:** A maneira segura de conceder permissões a instâncias sem usar chaves de acesso estáticas.
- **Introdução:**
    O roteamento dita o fluxo do tráfego. Aprenderemos como as tabelas de rotas definem uma sub-rede como pública ou privada. Veremos como o IGW permite a comunicação bidirecional para recursos públicos e como o NAT Gateway permite a comunicação unidirecional (de saída) para recursos privados, um padrão de arquitetura essencial.
- **Fontes de Estudo:**
    - **AWS Docs:** [Configurar tabelas de rotas](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
    - **AWS Docs:** [Conectar-se à internet usando um gateway da internet](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
    - **AWS Docs:** [NAT gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
    - **AWS Docs:** [IAM roles para Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)

---

## Aulas 2-8: Aprofundando no VPC Advanced

As 7 aulas seguintes são dedicadas ao conteúdo do curso avançado, divididas logicamente para garantir a profundidade em cada tópico.

### Aula 2: Roteamento Avançado e Acesso Privado
- **Tópicos:**
    - **Internet Gateway vs. NAT Gateway:** Análise comparativa profunda (arquitetura, performance, custo, casos de uso).
    - **VPC Endpoints (Gateway):** Acesso privado e otimizado ao S3 e DynamoDB. Análise do impacto no roteamento e na segurança.
- **Introdução:**
    Vamos além do roteamento básico para entender as nuances de performance e custo entre IGW e NAT Gateway. O foco principal será em VPC Endpoints, a tecnologia que permite trazer os serviços da AWS para dentro da sua rede privada, eliminando custos de NAT e aumentando a segurança.
- **Fontes de Estudo:**
    - **AWS Docs:** [VPC endpoints](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-endpoints.html)
    - **Artigo:** [AWS PrivateLink - Conceitos](https://aws.amazon.com/privatelink/getting-started/)

### Aula 3: Exposição de Serviços e Acesso Privado a Serviços
- **Tópicos:**
    - **Expondo a Rede Privada:** O padrão de Proxy Reverso com Application Load Balancer (ALB).
    - **VPC Endpoints (Interface - PrivateLink):** Acesso privado à maioria dos serviços AWS (SQS, SNS, API Gateway) e a serviços de terceiros. Análise do impacto no DNS.
- **Introdução:**
    Como expor uma aplicação que roda em uma sub-rede privada de forma segura? A resposta é o ALB. Em seguida, continuaremos nossa jornada com VPC Endpoints, focando no tipo Interface (PrivateLink), que funciona para quase todos os outros serviços e é a base para a conectividade privada em arquiteturas modernas.
- **Fontes de Estudo:**
    - **AWS Docs:** [O que é um Application Load Balancer?](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)
    - **AWS Docs:** [Acessar um serviço da AWS usando um endpoint da VPC de interface](https://docs.aws.amazon.com/vpc/latest/userguide/vpce-interface.html)

### Aula 4: Segurança Avançada em Camadas
- **Tópicos:**
    - **ACLS e Security Groups Avançados:** Estratégias de Defesa em Profundidade.
    - **Controle Granular de Acesso com IAM:** Implementando ABAC (Attribute-Based Access Control) com tags para um gerenciamento de permissões escalável.
- **Introdução:**
    A segurança é mais do que apenas abrir e fechar portas. Veremos como usar SGs e NACLs juntos em uma estratégia de defesa em profundidade. O destaque será o ABAC, um modelo de permissões moderno que usa tags para definir o acesso, permitindo uma governança muito mais escalável e flexível do que o RBAC tradicional.
- **Fontes de Estudo:**
    - **Tutorial AWS:** [Exemplos de políticas baseadas em atributos (ABAC)](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_abac.html)
    - **Blog AWS:** [Scale permissions management in AWS with attribute-based access control](https://aws.amazon.com/blogs/security/scale-permissions-management-in-aws-with-attribute-based-access-control/)

### Aula 5: Criptografia e Acesso Seguro
- **Tópicos:**
    - **Criptografia em Trânsito:** Implementando terminação TLS/SSL em um Application Load Balancer com o AWS Certificate Manager (ACM).
    - **Configurando um Bastion Host (Jump Server):** O padrão de Ponto de Acesso Único e o uso seguro do SSH Agent Forwarding.
    - **Alternativa ao Bastion Host:** AWS Systems Manager Session Manager.
- **Introdução:**
    Proteger os dados em trânsito é obrigatório. Implementaremos HTTPS em nosso ALB. Em seguida, abordaremos o problema do acesso administrativo seguro a instâncias privadas, comparando a abordagem tradicional do Bastion Host com a solução moderna e mais segura do Session Manager.
- **Fontes de Estudo:**
    - **AWS Docs:** [O que é o AWS Certificate Manager?](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html)
    - **AWS Docs:** [O que é o AWS Systems Manager Session Manager?](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
    - **Artigo:** [Securely connect to Linux instances running in a private Amazon VPC](https://aws.amazon.com/blogs/security/securely-connect-to-linux-instances-running-in-a-private-amazon-vpc/)

### Aula 6: Monitoramento, Logs e Observabilidade
- **Tópicos:**
    - **VPC Flow Logs:** Análise de tráfego de rede para segurança e troubleshooting.
    - **AWS CloudTrail:** Auditoria de todas as chamadas de API na conta.
    - **Monitoramento com CloudWatch:** Criando dashboards e alarmes proativos para métricas de rede chave (ALB, NAT GW, EC2).
- **Introdução:**
    Você não pode proteger ou consertar o que não pode ver. Esta aula é sobre observabilidade. Vamos habilitar e analisar os dois tipos de logs mais importantes (Flow Logs para o plano de dados, CloudTrail para o plano de controle) e usar o CloudWatch para passar de um monitoramento reativo para um proativo.
- **Fontes de Estudo:**
    - **AWS Docs:** [Registrar em log o tráfego IP usando o VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
    - **AWS Docs:** [O que é o AWS CloudTrail?](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html)
    - **AWS Docs:** [Métricas e dimensões do Amazon CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/aws-services-cloudwatch-metrics.html)

### Aula 7: Automação com AWS CLI e Introdução ao Terraform
- **Tópicos:**
    - **AWS CLI Avançado:** Filtros do lado do servidor e queries JMESPath do lado do cliente.
    - **Scripts de Automação:** Escrevendo scripts Bash imperativos para provisionar recursos.
    - **Introdução ao Terraform:** O paradigma da Infraestrutura como Código (IaC) e a abordagem declarativa.
    - **Fluxo de Trabalho do Terraform:** `init`, `plan`, `apply`, `destroy`.
- **Introdução:**
    A automação é a chave para a escala e a consistência na nuvem. Começaremos com a abordagem imperativa, escrevendo scripts com a AWS CLI. Em seguida, introduziremos o Terraform, a ferramenta declarativa que revolucionou a IaC, e aprenderemos seu fluxo de trabalho fundamental.
- **Fontes de Estudo:**
    - **AWS Docs:** [Referência de comandos da AWS CLI](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html)
    - **Tutorial:** [Introdução ao Terraform na AWS](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)
    - **Conceito:** [Imperative vs. Declarative IaC](https://www.hashicorp.com/resources/imperative-vs-declarative-infrastructure-as-code)

### Aula 8: Infraestrutura como Código com Terraform Avançado
- **Tópicos:**
    - **Templates Terraform Avançados:** Composição e Reutilização com Módulos.
    - **Estrutura de um Módulo:** `variables.tf`, `main.tf`, `outputs.tf`.
    - **Refatoração:** Convertendo um template monolítico em um módulo VPC reutilizável.
    - **Fontes de Módulos:** Terraform Registry, Git.
- **Introdução:**
    Nesta aula final, aplicaremos princípios de engenharia de software à nossa infraestrutura. Aprenderemos a quebrar nosso código Terraform em módulos reutilizáveis, a "caixa de LEGO" da IaC. Isso nos permitirá construir infraestruturas complexas de forma rápida, consistente e segura, completando nossa jornada do essencial ao avançado.
- **Fontes de Estudo:**
    - **Terraform Docs:** [Módulos do Terraform](https://developer.hashicorp.com/terraform/language/modules)
    - **Terraform Registry:** [Módulo VPC da AWS](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
