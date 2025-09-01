
# Aula 1: Nivelamento - Dominando o Essencial da VPC

**Duração Total:** 3 Horas

## Objetivos da Aula

- **Compreender** os conceitos fundamentais de uma Virtual Private Cloud (VPC).
- **Diferenciar** entre uma VPC Padrão e uma VPC Customizada.
- **Identificar** e configurar os componentes essenciais de uma VPC: Sub-redes, Tabelas de Rotas, Internet Gateway e NAT Gateway.
- **Implementar** as melhores práticas de segurança em camadas usando Security Groups e Network ACLs.
- **Provisionar** uma VPC básica usando tanto o Console da AWS quanto o Terraform.

---

## Bloco 1: Fundamentos da Rede Virtual (90 minutos)

### Parte 1: Teoria - O que é uma VPC? (45 min)

- **Conceitos Chave:**
    - **Software-Defined Networking (SDN):** A VPC é a sua rede definida por software, um data center virtual e privado na nuvem da AWS. Abstrai a complexidade da infraestrutura física.
    - **Isolamento Lógico:** Sua VPC é completamente isolada de outras VPCs, mesmo na mesma conta, a menos que você configure explicitamente a conectividade.
    - **VPC Padrão vs. Customizada:**
        - **Padrão:** Criada automaticamente pela AWS para facilitar o início. É uma rede "flat" e pública por padrão. Ideal para testes rápidos, mas **não recomendada para produção**.
        - **Customizada:** Você projeta do zero. Essencial para produção, pois oferece controle total sobre segurança, endereçamento e topologia.
    - **Planejamento de Endereçamento IP (CIDR):**
        - O passo mais crítico. Um bloco CIDR (ex: `10.0.0.0/16`) define o espaço de IP privado da sua VPC.
        - Deve ser escolhido com cuidado para não se sobrepor a outras redes (outras VPCs, redes on-premises) com as quais você possa precisar se conectar no futuro.
    - **Sub-redes (Subnets):**
        - Segmentos da sua VPC que permitem agrupar recursos.
        - Vinculadas a uma única Zona de Disponibilidade (AZ), sendo a base para a alta disponibilidade.
        - **Pública:** Se sua tabela de rotas associada tem uma rota para um Internet Gateway.
        - **Privada:** Se sua tabela de rotas **não** tem uma rota para um Internet Gateway.

### Parte 2: Demonstração (Console) - Construindo a Estrutura da VPC (45 min)

**Objetivo:** Criar manualmente uma VPC customizada com uma sub-rede pública e uma privada.

1.  **Criar a VPC:**
    - Navegue até o **Console da VPC**.
    - **Name tag:** `Lab-VPC`
    - **IPv4 CIDR block:** `10.0.0.0/16`
    - *Explicação:* Estamos alocando ~65.000 IPs para nossa rede privada.

2.  **Criar Sub-redes:**
    - Crie duas sub-redes dentro da `Lab-VPC`.
    - **Sub-rede Pública:**
        - **Name tag:** `lab-subnet-public-1a`
        - **Availability Zone:** `us-east-1a` (ou a primeira da sua região)
        - **IPv4 CIDR block:** `10.0.1.0/24`
    - **Sub-rede Privada:**
        - **Name tag:** `lab-subnet-private-1a`
        - **Availability Zone:** `us-east-1a`
        - **IPv4 CIDR block:** `10.0.2.0/24`
    - *Explicação:* Segmentamos nossa VPC em duas "vizinhanças", cada uma com ~250 IPs. Ambas estão na mesma AZ por enquanto.

3.  **Criar e Anexar o Internet Gateway (IGW):**
    - Crie um **Internet Gateway** com o nome `Lab-IGW`.
    - Após a criação, **anexe-o (Attach)** à sua `Lab-VPC`.
    - *Explicação:* Este é o portão da nossa VPC para a internet. Sem ele, não há como o tráfego entrar ou sair.

4.  **Configurar o Roteamento:**
    - **Tabela de Rotas Pública:**
        - Crie uma nova tabela de rotas: `Lab-Public-RT`.
        - **Edite suas rotas:** Adicione uma rota `0.0.0.0/0` com o **Target** sendo o `Lab-IGW`.
        - **Associe** esta tabela à sub-rede `lab-subnet-public-1a`.
    - **Tabela de Rotas Privada:**
        - Inspecione a tabela de rotas **Principal (Main)**. Ela já está associada à `lab-subnet-private-1a`.
        - Verifique que ela contém **apenas** a rota `local` (`10.0.0.0/16`).
    - *Explicação:* A tabela de rotas é o "GPS" da sub-rede. Ao dar à sub-rede pública um mapa para o IGW, nós a tornamos pública. Ao não dar esse mapa à sub-rede privada, ela permanece isolada.

---

## Bloco 2: Segurança em Camadas (60 minutos)

### Parte 1: Teoria - Firewalls da VPC (30 min)

- **Security Groups (SGs):**
    - **Stateful:** Se você permite tráfego de entrada, a resposta é automaticamente permitida na saída.
    - **Nível da Instância (ENI):** Atua como o segurança pessoal de cada instância.
    - **Apenas Regras de `Allow`:** Nega tudo por padrão. Força o princípio do menor privilégio.
    - **Referências de Grupo:** A melhor prática para comunicação interna. Em vez de permitir um IP, você permite outro Security Group (ex: `App-SG` permite tráfego do `Web-SG`).
- **Network ACLs (NACLs):**
    - **Stateless:** Você deve permitir explicitamente tanto o tráfego de entrada quanto o de **resposta** na saída.
    - **Nível da Sub-rede:** Atua como o guarda de fronteira da "vizinhança".
    - **Regras `Allow` e `Deny`:** Processadas em ordem numérica. Ideal para `blacklisting` de IPs maliciosos.
- **Defesa em Profundidade:** Use ambos. NACLs para bloqueios amplos no perímetro e SGs para controle refinado na aplicação.

### Parte 2: Demonstração (Console) - Configurando os Firewalls (30 min)

**Objetivo:** Criar SGs para uma arquitetura Web/App e uma NACL para bloquear um IP.

1.  **Criar Security Groups:**
    - **`WebServer-SG`:**
        - **Inbound:** `Allow HTTP (80)` e `HTTPS (443)` from `0.0.0.0/0`. `Allow SSH (22)` from `My IP`.
    - **`AppServer-SG`:**
        - **Inbound:** `Allow TCP 8080` from **Source: `WebServer-SG`**.
    - *Explicação:* Demonstração da microssegmentação. Apenas o WebServer pode falar com o AppServer na porta da aplicação.

2.  **Configurar Network ACL:**
    - Selecione a NACL associada à `lab-subnet-public-1a`.
    - **Adicione uma regra de `DENY`:**
        - **Rule #:** `90` (para ser processada antes da regra `ALLOW` padrão `100`).
        - **Type:** `All Traffic`
        - **Source:** `1.2.3.4/32` (um IP fictício a ser bloqueado).
        - **Allow/Deny:** `DENY`.
    - *Explicação:* Mostra como a NACL pode ser usada para bloquear tráfego indesejado antes mesmo que ele chegue ao Security Group.

---

## Bloco 3: Conectividade e Automação (30 minutos)

### Parte 1: Teoria e Demonstração (Console) - Acesso de Saída e Permissões (15 min)

- **NAT Gateway:**
    - **Problema:** Como uma instância em uma sub-rede privada (ex: um servidor de aplicação) acessa a internet para baixar atualizações ou usar APIs?
    - **Solução:** O NAT Gateway. Ele reside na **sub-rede pública** e usa **PAT (Port Address Translation)**.
    - **Configuração:**
        1. Crie um **NAT Gateway** na sub-rede pública e associe um **Elastic IP** a ele.
        2. Na **tabela de rotas da sub-rede privada**, adicione uma rota `0.0.0.0/0` com o **Target** sendo o NAT Gateway.
- **IAM Roles para EC2:**
    - **Problema:** Armazenar chaves de acesso estáticas em uma instância é um grande risco de segurança.
    - **Solução:** Anexe uma **IAM Role** à instância. A instância assume a role e obtém credenciais **temporárias** e rotacionadas automaticamente para acessar outros serviços da AWS.

### Parte 2: Demonstração (Terraform) - Infraestrutura como Código (15 min)

**Objetivo:** Mostrar como a mesma VPC pode ser definida de forma declarativa.

- **Apresentar o código `main.tf`:**

```hcl
# main.tf - Exemplo de VPC com Terraform

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "lab_vpc_tf" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "Terraform-VPC-Essential"
  }
}

resource "aws_subnet" "public_subnet_tf" {
  vpc_id     = aws_vpc.lab_vpc_tf.id
  cidr_block = "10.1.1.0/24"
  tags = {
    Name = "Terraform-Public-Subnet"
  }
}

resource "aws_internet_gateway" "igw_tf" {
  vpc_id = aws_vpc.lab_vpc_tf.id
  tags = {
    Name = "Terraform-IGW"
  }
}

resource "aws_route_table" "public_rt_tf" {
  vpc_id = aws_vpc.lab_vpc_tf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_tf.id
  }

  tags = {
    Name = "Terraform-Public-RT"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet_tf.id
  route_table_id = aws_route_table.public_rt_tf.id
}
```

- **Executar o fluxo de trabalho do Terraform:**
    1.  `terraform init` - Baixa o provedor da AWS.
    2.  `terraform plan` - Mostra o que será criado.
    3.  `terraform apply` - Cria a infraestrutura.
    4.  `terraform destroy` - Destrói a infraestrutura.
- *Explicação:* Introduz o conceito de IaC, mostrando como o código se torna a fonte da verdade para a infraestrutura, garantindo consistência e repetibilidade.

---
