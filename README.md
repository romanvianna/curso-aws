# Estudos e Laboratórios de AWS

Bem-vindo ao meu repositório de estudos da AWS! Este espaço é dedicado a documentar meu aprendizado, laboratórios práticos e configurações de referência para diversos serviços e arquiteturas na nuvem da Amazon Web Services.

O objetivo é criar um guia de referência pessoal e um glossário de termos que possa ser consultado para reforçar o conhecimento e acelerar a implementação de soluções no futuro.

## Estrutura do Repositório

O repositório está organizado em módulos, cada um focado em um serviço ou conceito específico da AWS. Atualmente, o foco principal é em **Redes com a VPC**.

A estrutura de cada módulo é a seguinte:

-   **/serviço (ex: vpc/):** Diretório raiz para um serviço específico.
    -   **/nível (ex: essential/, advanced/, plus/):** Nível de profundidade do conteúdo.
        -   **/módulo (ex: modulo-01.../):** Agrupamento de aulas sobre um tópico.
            -   **/aula (ex: 1.1-o-que-e-vpc/):** Conteúdo específico de uma aula.
                -   `README.md`: A teoria, conceitos e o guia do laboratório prático.
                -   `main.tf`: Exemplo de implementação declarativa com Terraform.
                -   `examples.sh`: Exemplos de comandos imperativos com a AWS CLI.

---

## Glossário de Termos e Conceitos

Aqui está um resumo dos principais conceitos abordados nos módulos de VPC.

### 1. Fundamentos da VPC

-   **VPC (Virtual Private Cloud):** Seu data center virtual e isolado na nuvem da AWS. É uma implementação de Rede Definida por Software (SDN) que lhe dá controle total sobre seu ambiente de rede.
-   **CIDR (Classless Inter-Domain Routing):** O bloco de endereços IP privados que define o espaço de endereçamento da sua VPC (ex: `10.0.0.0/16`).
-   **Sub-rede (Subnet):** Uma subdivisão de uma VPC. Cada sub-rede reside em uma única Zona de Disponibilidade (AZ) e é usada para agrupar recursos.
    -   **Sub-rede Pública:** Possui uma rota em sua tabela de rotas que aponta para um Internet Gateway. Recursos nela podem ter IPs públicos.
    -   **Sub-rede Privada:** **Não** possui uma rota para um Internet Gateway, isolando seus recursos da internet.
-   **Tabela de Rotas (Route Table):** Um conjunto de regras (rotas) que determina para onde o tráfego de rede de uma sub-rede é direcionado.
-   **Internet Gateway (IGW):** O componente que permite a comunicação entre sua VPC e a internet. Atua como um alvo de roteamento e realiza NAT 1:1 para instâncias com IPs públicos.

### 2. Segurança de Rede

-   **Security Group (SG):** Um firewall **stateful** (com estado) que atua no nível da instância (ENI). Nega tudo por padrão e só permite regras de `Allow`. É a principal ferramenta para controle de acesso de aplicações.
-   **Network ACL (NACL):** Um firewall **stateless** (sem estado) que atua no nível da sub-rede. Processa regras em ordem numérica e suporta regras de `Allow` e `Deny`. Ideal para blacklisting de IPs.
-   **Defesa em Profundidade:** A estratégia de usar múltiplas camadas de segurança (NACLs + SGs + Firewall de Host) para proteger os recursos.
-   **IAM Role para EC2:** O método seguro e recomendado para conceder permissões a instâncias EC2 para que elas possam acessar outros serviços da AWS, sem armazenar credenciais de longa duração.

### 3. Conectividade

-   **NAT Gateway:** Um serviço gerenciado que permite que instâncias em uma sub-rede privada iniciem conexões de saída para a internet, mas impede conexões de entrada não solicitadas.
-   **VPC Endpoints:** Permitem conectar sua VPC a serviços da AWS de forma privada, sem que o tráfego passe pela internet.
    -   **Gateway Endpoint:** Para S3 e DynamoDB. Gratuito e baseado em roteamento.
    -   **Interface Endpoint (PrivateLink):** Para a maioria dos outros serviços. Cria uma ENI na sua sub-rede e tem um custo por hora.
-   **VPC Peering:** Conecta duas VPCs de forma privada, 1-para-1. Não é transitivo.
-   **Transit Gateway (TGW):** Um roteador de nuvem centralizado que atua como um hub para conectar centenas de VPCs e redes on-premises de forma escalável (modelo Hub-and-Spoke).
-   **Site-to-Site VPN:** Cria um túnel IPsec criptografado através da internet para conectar sua VPC a uma rede on-premises.
-   **Direct Connect (DX):** Fornece uma conexão de fibra óptica privada e dedicada entre seu data center e a AWS.

### 4. Automação e Gerenciamento

-   **AWS CLI:** A Interface de Linha de Comando para gerenciar recursos da AWS de forma programática. Essencial para automação e scripting.
-   **Terraform (IaC):** A principal ferramenta de Infraestrutura como Código (IaC) para definir e provisionar infraestrutura de forma declarativa, consistente e repetível.
-   **GitOps:** Um modelo operacional que usa um repositório Git como a única fonte da verdade para a infraestrutura, automatizando o provisionamento através de pipelines de CI/CD.
-   **AWS Organizations:** Serviço para gerenciar centralmente um ambiente com múltiplas contas AWS, aplicando políticas de governança com SCPs.
-   **AWS Config:** Um serviço para auditoria contínua que monitora a configuração dos seus recursos e os avalia em relação a regras de conformidade.
-   **Amazon GuardDuty:** Um serviço de detecção de ameaças que usa Machine Learning para identificar atividades maliciosas em sua conta.
-   **AWS Security Hub:** Centraliza e prioriza alertas de segurança de múltiplos serviços (GuardDuty, Inspector, etc.) e verifica a conformidade com padrões como o CIS Benchmark.

---

## Próximos Cursos

*(Esta seção será atualizada à medida que novos módulos de estudo forem adicionados.)*
