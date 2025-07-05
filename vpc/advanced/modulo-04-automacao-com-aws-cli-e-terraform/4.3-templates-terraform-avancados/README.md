# Módulo 4.3: Templates Terraform Avançados

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Pré-requisitos

*   Conhecimento sólido dos conceitos básicos do Terraform (recursos, provedores, `init`, `plan`, `apply`).
*   Familiaridade com a sintaxe HCL (HashiCorp Configuration Language).
*   Compreensão de como a Infraestrutura como Código (IaC) funciona.

## Objetivos

*   Entender os princípios de design de software de **Reutilização** e **Composição** aplicados à Infraestrutura como Código.
*   Aplicar esses princípios usando **Módulos Terraform** para organizar e reutilizar configurações de infraestrutura.
*   Aprender a estrutura de um módulo Terraform, incluindo `variables.tf`, `main.tf` e `outputs.tf`.
*   Refatorar um template Terraform monolítico em um módulo VPC reutilizável, demonstrando a separação de responsabilidades.
*   Explorar diferentes fontes de módulos (locais, Terraform Registry, Git) e suas aplicações.
*   Discutir as melhores práticas para o desenvolvimento e uso de módulos em ambientes de produção.

---

## 1. Composição e Reutilização com Módulos (Teoria - 45 min)

Em engenharia de software, não escrevemos uma aplicação inteira em uma única função gigante. Nós a quebramos em componentes menores e reutilizáveis: funções, classes, pacotes. Isso torna o código mais fácil de entender, testar e manter. O mesmo princípio se aplica à Infraestrutura como Código.

À medida que sua infraestrutura cresce, um único arquivo `main.tf` com centenas de recursos se torna um "template monolítico" - difícil de ler, propenso a erros, difícil de manter e impossível de reutilizar em outros projetos ou ambientes. O Terraform resolve isso através dos **Módulos**.

### O que é um Módulo Terraform?

Um **módulo** é um contêiner para um conjunto de recursos do Terraform que são usados juntos. Pense em um módulo como uma "caixa preta" que executa uma função específica, encapsulando a lógica de provisionamento de uma parte da sua infraestrutura. Ele tem:

*   **Entradas (Input Variables):** Parâmetros que você passa para o módulo para customizar seu comportamento (definidos em `variables.tf`). Ex: o bloco CIDR de uma VPC, o nome de um bucket S3.
*   **Lógica Interna (Resources):** Os blocos `resource` que definem a infraestrutura que o módulo cria (definidos em `main.tf`). Esta é a implementação interna do módulo.
*   **Saídas (Output Values):** Resultados que o módulo retorna para que possam ser usados por outros recursos ou módulos (definidos em `outputs.tf`). Ex: o ID da VPC criada, o ARN de um Load Balancer.

### O Poder da Composição

Os módulos permitem a **composição**. Você pode construir peças de infraestrutura complexas montando módulos menores, como se fossem blocos de LEGO. Isso promove a modularidade e a reutilização.

*   Você pode ter um módulo `vpc` que cria a rede base (VPC, sub-redes, IGW, tabelas de rotas).
*   Um módulo `security_group` que cria Security Groups com regras padrão.
*   Um módulo `ec2_instance` que lança uma instância com configurações padrão (AMI, tipo, SG).

Seu código de nível superior (o **módulo raiz**, que é o diretório onde você executa `terraform apply`) se torna muito mais simples e legível. Ele apenas **compõe** esses módulos, passando os parâmetros necessários:

```hcl
// Cria a nossa rede base usando um módulo VPC
module "networking" {
  source = "./modules/vpc" // Caminho para o módulo local
  vpc_cidr   = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
}

// Cria uma instância DENTRO da rede criada acima
module "web_server" {
  source    = "./modules/ec2_instance"
  vpc_id    = module.networking.vpc_id // Usa a saída do módulo de rede
  subnet_id = module.networking.public_subnet_id // Usa a saída do módulo de rede
  instance_type = "t2.micro"
}
```

### Estrutura de um Módulo Reutilizável

Um módulo bem estruturado promove a clareza e a reutilização. A estrutura de diretórios típica para um módulo é:

```
my-terraform-project/
├── main.tf (módulo raiz)
├── variables.tf
├── outputs.tf
├── modules/
│   ├── vpc/
│   │   ├── main.tf (recursos da VPC)
│   │   ├── variables.tf (variáveis de entrada da VPC)
│   │   ├── outputs.tf (saídas da VPC)
│   │   └── README.md (documentação do módulo VPC)
│   └── ec2_instance/
│       ├── main.tf (recursos da instância EC2)
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
```

*   `main.tf`: Contém a lógica principal (os blocos `resource`) que o módulo provisiona.
*   `variables.tf`: **Define a API do seu módulo**. Declara todas as variáveis de entrada que o módulo aceita, incluindo tipos, descrições e valores padrão. Isso torna o módulo configurável.
*   `outputs.tf`: **Define o contrato de retorno do seu módulo**. Declara todos os valores que o módulo expõe para o mundo exterior, permitindo que outros módulos ou o módulo raiz consumam esses valores.
*   `README.md`: Documentação essencial que explica o propósito do módulo, suas variáveis de entrada, suas saídas e exemplos de uso. Crucial para a reutilização.

### Fontes de Módulos

Os módulos podem ser carregados de diversas fontes:

*   **Local:** `source = "./modules/vpc"` (ideal para módulos específicos do seu projeto ou para desenvolvimento local).
*   **Terraform Registry:** `source = "terraform-aws-modules/vpc/aws"` (um registro público de módulos de alta qualidade e mantidos pela comunidade ou pela HashiCorp. Usar módulos da comunidade para tarefas comuns, como criar uma VPC, é uma prática recomendada que economiza tempo, incorpora as melhores práticas e é testado por muitos usuários).
*   **Git:** `source = "git::https://example.com/vpc.git?ref=v1.2.0"` (para módulos armazenados em repositórios Git privados ou públicos).

Usar módulos transforma a IaC de escrever scripts para projetar sistemas a partir de componentes testados e reutilizáveis, acelerando o desenvolvimento e garantindo a consistência e a qualidade da infraestrutura.

---

## 2. Deploy Completo via Terraform (Prática - 75 min)

Neste laboratório, vamos aplicar os princípios de composição e reutilização, refatorando nosso template Terraform (do Módulo 4.2) em um módulo VPC local. Isso simula um cenário onde uma organização padroniza a criação de VPCs e deseja reutilizar essa configuração em múltiplos projetos.

### Cenário: Padronização de VPCs para Múltiplos Projetos

Uma empresa possui vários projetos, e cada um requer sua própria VPC com uma estrutura de rede padrão (sub-redes públicas e privadas, Internet Gateway, tabelas de rotas). Para evitar a duplicação de código e garantir a consistência, a equipe de infraestrutura decide criar um módulo Terraform de VPC que pode ser facilmente reutilizado por todas as equipes.

### Roteiro Prático

**Passo 1: Estruturar os Diretórios do Projeto**
1.  Comece no seu diretório `terraform-first-vpc` (criado no Módulo 4.2) ou crie um novo diretório para este laboratório.
2.  Crie a seguinte estrutura de diretórios:
    ```
    . (diretório raiz do projeto)
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
        └── vpc/
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
    ```
    Comandos para criar a estrutura:
    `mkdir -p modules/vpc`
    `touch main.tf variables.tf outputs.tf`
    `touch modules/vpc/main.tf modules/vpc/variables.tf modules/vpc/outputs.tf`

**Passo 2: Criar o Módulo VPC (a "Função" Reutilizável)**

Vamos mover a lógica de criação da VPC, sub-rede e Internet Gateway para dentro do módulo `modules/vpc/`.

1.  **`modules/vpc/variables.tf` (Definir as Entradas do Módulo):**
    ```hcl
    variable "vpc_cidr" {
      description = "The CIDR block for the VPC."
      type        = string
    }

    variable "public_subnet_cidr" {
      description = "The CIDR block for the public subnet."
      type        = string
    }

    variable "private_subnet_cidr" {
      description = "The CIDR block for the private subnet."
      type        = string
      default     = null # Opcional: pode ser nulo se não houver sub-rede privada
    }

    variable "project_name" {
      description = "The name of the project for tagging resources."
      type        = string
    }

    variable "availability_zone" {
      description = "The Availability Zone for the subnets."
      type        = string
    }
    ```

2.  **`modules/vpc/main.tf` (Definir a Lógica de Recursos do Módulo):**
    Mova a lógica de criação de recursos para este arquivo, usando as variáveis definidas.
    ```hcl
    # Recurso: VPC
    resource "aws_vpc" "this" {
      cidr_block = var.vpc_cidr

      tags = {
        Name = "${var.project_name}-VPC"
      }
    }

    # Recurso: Internet Gateway
    resource "aws_internet_gateway" "this" {
      vpc_id = aws_vpc.this.id

      tags = {
        Name = "${var.project_name}-IGW"
      }
    }

    # Recurso: Sub-rede Pública
    resource "aws_subnet" "public" {
      vpc_id                  = aws_vpc.this.id
      cidr_block              = var.public_subnet_cidr
      availability_zone       = var.availability_zone
      map_public_ip_on_launch = true

      tags = {
        Name = "${var.project_name}-Public-Subnet"
      }
    }

    # Recurso: Tabela de Rotas Pública
    resource "aws_route_table" "public" {
      vpc_id = aws_vpc.this.id

      route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.this.id
      }

      tags = {
        Name = "${var.project_name}-Public-RT"
      }
    }

    # Recurso: Associação da Tabela de Rotas Pública à Sub-rede Pública
    resource "aws_route_table_association" "public" {
      subnet_id      = aws_subnet.public.id
      route_table_id = aws_route_table.public.id
    }

    # Recurso: Sub-rede Privada (opcional, criada apenas se private_subnet_cidr for fornecido)
    resource "aws_subnet" "private" {
      count = var.private_subnet_cidr != null ? 1 : 0

      vpc_id            = aws_vpc.this.id
      cidr_block        = var.private_subnet_cidr
      availability_zone = var.availability_zone

      tags = {
        Name = "${var.project_name}-Private-Subnet"
      }
    }

    # Recurso: Tabela de Rotas Privada (opcional, criada apenas se private_subnet_cidr for fornecido)
    resource "aws_route_table" "private" {
      count = var.private_subnet_cidr != null ? 1 : 0

      vpc_id = aws_vpc.this.id

      tags = {
        Name = "${var.project_name}-Private-RT"
      }
    }

    # Recurso: Associação da Tabela de Rotas Privada à Sub-rede Privada (opcional)
    resource "aws_route_table_association" "private" {
      count = var.private_subnet_cidr != null ? 1 : 0

      subnet_id      = aws_subnet.private[0].id
      route_table_id = aws_route_table.private[0].id
    }
    ```

3.  **`modules/vpc/outputs.tf` (Definir as Saídas do Módulo):**
    ```hcl
    output "vpc_id" {
      description = "The ID of the VPC created by the module."
      value       = aws_vpc.this.id
    }

    output "public_subnet_id" {
      description = "The ID of the public subnet created by the module."
      value       = aws_subnet.public.id
    }

    output "private_subnet_id" {
      description = "The ID of the private subnet created by the module (if any)."
      value       = var.private_subnet_cidr != null ? aws_subnet.private[0].id : null
    }

    output "internet_gateway_id" {
      description = "The ID of the Internet Gateway created by the module."
      value       = aws_internet_gateway.this.id
    }
    ```

**Passo 3: Atualizar o Módulo Raiz (o "Chamador")**

Agora, o `main.tf` no diretório raiz será muito mais simples, apenas chamando o módulo VPC.

1.  Edite o arquivo `main.tf` no diretório raiz do seu projeto.
2.  Substitua seu conteúdo antigo pelo seguinte código, que agora apenas **chama** nosso módulo VPC local.
    ```hcl
    # Bloco de configuração do Terraform para especificar o provedor
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }

    # Configuração do provedor AWS
    provider "aws" {
      region = "us-east-1"
    }

    # Chamando nosso módulo VPC local
    module "my_lab_vpc" {
      source = "./modules/vpc" # Caminho para o diretório do módulo

      # Passando os valores para as variáveis de entrada do módulo
      project_name        = "Helios"
      vpc_cidr            = "10.250.0.0/16"
      public_subnet_cidr  = "10.250.1.0/24"
      private_subnet_cidr = "10.250.2.0/24" # Opcional: defina como null se não quiser sub-rede privada
      availability_zone   = "us-east-1a"
    }

    # Usando as saídas do módulo para referência ou para outros recursos
    output "lab_vpc_id" {
      description = "VPC ID returned from the module"
      value       = module.my_lab_vpc.vpc_id
    }

    output "lab_public_subnet_id" {
      description = "Public Subnet ID returned from the module"
      value       = module.my_lab_vpc.public_subnet_id
    }

    output "lab_private_subnet_id" {
      description = "Private Subnet ID returned from the module"
      value       = module.my_lab_vpc.private_subnet_id
    }
    ```

3.  Crie ou atualize o arquivo `variables.tf` no diretório raiz (se você tiver variáveis globais).
4.  Crie ou atualize o arquivo `outputs.tf` no diretório raiz (se você tiver outputs globais).

**Passo 4: Executar o Terraform**
1.  No diretório raiz do seu projeto (`terraform-first-vpc`), execute `terraform init`. Ele detectará e inicializará o módulo local.
2.  Execute `terraform plan`. Ele mostrará que os recursos da VPC serão criados dentro do contexto do módulo.
3.  Execute `terraform apply` e confirme com `yes`.
4.  **Validação:** Verifique no console da AWS que a `Helios-VPC` foi criada com suas sub-redes e Internet Gateway. O código do módulo raiz está limpo e legível, e a complexidade está encapsulada no módulo.
5.  Execute `terraform destroy` para limpar os recursos.

Este laboratório demonstra uma abordagem de IaC muito mais madura e escalável. Ao modularizar seu código, você cria blocos de construção que podem ser compostos para construir qualquer ambiente, acelerando o desenvolvimento e garantindo a consistência.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Módulos Pequenos e Focados:** Crie módulos que façam uma única coisa bem feita (ex: um módulo para VPC, um para EC2, um para S3). Isso aumenta a reutilização e a manutenibilidade.
*   **Documentação do Módulo:** Sempre inclua um `README.md` detalhado em cada módulo, explicando seu propósito, variáveis de entrada, saídas e exemplos de uso. Isso é crucial para que outros (e você mesmo no futuro) possam entender e usar o módulo.
*   **Versionamento de Módulos:** Se você estiver usando módulos de fontes externas (Git, Registry), especifique uma versão. Isso garante que suas implantações sejam consistentes e previsíveis.
*   **Testes de Módulos:** Para módulos complexos, considere escrever testes automatizados (ex: com Terratest) para garantir que eles funcionem como esperado e não introduzam regressões.
*   **Evite Variáveis Demais:** Não transforme cada atributo de um recurso em uma variável de entrada do módulo. Exponha apenas o que é realmente necessário para a flexibilidade e mantenha os padrões dentro do módulo.
*   **Use Módulos do Terraform Registry:** Para componentes comuns (VPC, EKS, RDS), prefira usar módulos bem mantidos do Terraform Registry. Eles geralmente incorporam as melhores práticas e são testados pela comunidade.
*   **Estrutura de Diretórios:** Mantenha uma estrutura de diretórios clara e consistente para seus projetos Terraform, separando o módulo raiz dos módulos reutilizáveis.
*   **Backend Remoto:** Para qualquer ambiente que não seja de desenvolvimento local, use um backend remoto (ex: S3 com DynamoDB) para armazenar o estado do Terraform de forma segura e colaborativa.
