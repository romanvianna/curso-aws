# Módulo 4.3: Templates Terraform Avançados

**Tempo de Aula:** 45 minutos de teoria, 75 minutos de prática

## Objetivos

- Entender os princípios de design de software de **Reutilização** e **Composição**.
- Aplicar esses princípios à Infraestrutura como Código usando Módulos Terraform.
- Aprender a estrutura de um módulo e como usar variáveis de entrada e valores de saída para criar componentes reutilizáveis.
- Refatorar um template Terraform monolítico em um módulo VPC reutilizável.

---

## 1. Composição e Reutilização com Módulos (Teoria - 45 min)

Em engenharia de software, não escrevemos uma aplicação inteira em uma única função gigante. Nós a quebramos em componentes menores e reutilizáveis: funções, classes, pacotes. Isso torna o código mais fácil de entender, testar e manter. 

O mesmo princípio se aplica à Infraestrutura como Código. À medida que sua infraestrutura cresce, um único arquivo `main.tf` com centenas de recursos se torna um "template monolítico" - difícil de ler, propenso a erros e impossível de reutilizar.

O Terraform resolve isso através dos **Módulos**.

### O que é um Módulo Terraform?

Um **módulo** é um contêiner para um conjunto de recursos do Terraform que são usados juntos. Pense em um módulo como uma "caixa preta" que executa uma função específica. Ele tem:

-   **Entradas (Input Variables):** Parâmetros que você passa para o módulo para customizar seu comportamento (ex: o bloco CIDR de uma VPC).
-   **Lógica Interna (Resources):** Os blocos `resource` que definem a infraestrutura que o módulo cria.
-   **Saídas (Output Values):** Resultados que o módulo retorna para que possam ser usados por outros recursos (ex: o ID da VPC criada).

### O Poder da Composição

Os módulos permitem a **composição**. Você pode construir peças de infraestrutura complexas montando módulos menores, como se fossem blocos de LEGO.

-   Você pode ter um módulo `vpc` que cria a rede base.
-   Um módulo `security` que cria Security Groups e NACLs.
-   Um módulo `ec2_instance` que lança uma instância com configurações padrão.

Seu código de nível superior (o **módulo raiz**) se torna muito mais simples e legível. Ele apenas **compõe** esses módulos, passando os parâmetros necessários:

```hcl
// Cria a nossa rede base
module "networking" {
  source = "./modules/vpc"
  cidr   = "10.0.0.0/16"
}

// Cria uma instância DENTRO da rede criada acima
module "web_server" {
  source    = "./modules/ec2_instance"
  vpc_id    = module.networking.vpc_id // Usa a saída do módulo de rede
  subnet_id = module.networking.public_subnet_id
}
```

### Estrutura de um Módulo Reutilizável

Um módulo bem estruturado promove a clareza e a reutilização.

-   `main.tf`: Contém a lógica principal (os blocos `resource`).
-   `variables.tf`: **Define a API do seu módulo**. Declara todas as variáveis de entrada que o módulo aceita, incluindo tipos, descrições e valores padrão.
-   `outputs.tf`: **Define o contrato de retorno do seu módulo**. Declara todos os valores que o módulo expõe para o mundo exterior.
-   `README.md`: Documentação essencial que explica o propósito do módulo, suas variáveis de entrada e suas saídas.

### Fontes de Módulos

-   **Local:** `source = "./modules/vpc"` (ideal para módulos específicos do seu projeto).
-   **Terraform Registry:** `source = "terraform-aws-modules/vpc/aws"` (um registro público de módulos de alta qualidade. Usar módulos da comunidade para tarefas comuns, como criar uma VPC, é uma prática recomendada que economiza tempo e incorpora as melhores práticas).
-   **Git:** `source = "git::https://example.com/vpc.git?ref=v1.2.0"`.

Usar módulos transforma a IaC de escrever scripts para projetar sistemas a partir de componentes testados e reutilizáveis.

---

## 2. Deploy Completo via Terraform (Prática - 75 min)

Neste laboratório, vamos aplicar os princípios de composição e reutilização, refatorando nosso template Terraform em um módulo VPC local.

### Cenário

Vamos pegar nosso código que cria uma VPC e uma sub-rede e encapsulá-lo em um módulo `vpc` reutilizável. O módulo raiz irá então chamar este módulo para provisionar a infraestrutura, demonstrando a separação de responsabilidades.

### Roteiro Prático

**Passo 1: Estruturar os Diretórios do Projeto**
1.  Comece no seu diretório `terraform-declarative-lab`.
2.  Crie a seguinte estrutura de diretórios:
    `mkdir -p modules/vpc`
3.  Crie os arquivos do módulo:
    `touch modules/vpc/main.tf`
    `touch modules/vpc/variables.tf`
    `touch modules/vpc/outputs.tf`

**Passo 2: Criar o Módulo VPC (a "Função")**

1.  **`modules/vpc/variables.tf` (Definir as Entradas):**
    ```hcl
    variable "vpc_cidr" {
      description = "The CIDR block for the VPC."
      type        = string
    }

    variable "subnet_cidr" {
      description = "The CIDR block for the subnet."
      type        = string
    }

    variable "project_name" {
      description = "The name of the project for tagging."
      type        = string
    }
    ```

2.  **`modules/vpc/main.tf` (Definir a Lógica):**
    Mova a lógica de criação de recursos para este arquivo, usando as variáveis.
    ```hcl
    resource "aws_vpc" "module_vpc" {
      cidr_block = var.vpc_cidr
      tags = { Name = "${var.project_name}-VPC" }
    }

    resource "aws_subnet" "module_subnet" {
      vpc_id     = aws_vpc.module_vpc.id
      cidr_block = var.subnet_cidr
      tags       = { Name = "${var.project_name}-Subnet" }
    }
    ```

3.  **`modules/vpc/outputs.tf` (Definir as Saídas):**
    ```hcl
    output "vpc_id" {
      description = "The ID of the VPC created by the module."
      value       = aws_vpc.module_vpc.id
    }

    output "subnet_id" {
      description = "The ID of the subnet created by the module."
      value       = aws_subnet.module_subnet.id
    }
    ```

**Passo 3: Atualizar o Módulo Raiz (o "Chamador")**

1.  Edite o arquivo `main.tf` no diretório raiz.
2.  Substitua seu conteúdo antigo pelo seguinte código, que agora apenas **chama** nosso módulo.
    ```hcl
    terraform {
      required_providers {
        aws = { source = "hashicorp/aws", version = "~> 4.0" }
      }
    }

    provider "aws" {
      region = "us-east-1"
    }

    # Chamando nosso módulo VPC local
    module "my_lab_vpc" {
      source = "./modules/vpc"

      # Passando os valores para as variáveis do módulo
      project_name = "Helios"
      vpc_cidr     = "10.250.0.0/16"
      subnet_cidr  = "10.250.1.0/24"
    }

    # Usando as saídas do módulo
    output "lab_vpc_id" {
      description = "VPC ID returned from the module"
      value       = module.my_lab_vpc.vpc_id
    }

    output "lab_subnet_id" {
      description = "Subnet ID returned from the module"
      value       = module.my_lab_vpc.subnet_id
    }
    ```

**Passo 4: Executar o Terraform**
1.  No diretório raiz, execute `terraform init`. Ele detectará e inicializará o módulo local.
2.  Execute `terraform plan`. Ele mostrará que 2 recursos serão criados (a VPC e a sub-rede, dentro do contexto do módulo).
3.  Execute `terraform apply` e confirme.
4.  **Validação:** Verifique no console da AWS que a `Helios-VPC` foi criada. O código do módulo raiz está limpo e legível, e a complexidade está encapsulada no módulo.
5.  Execute `terraform destroy` para limpar.

Este laboratório demonstra uma abordagem de IaC muito mais madura e escalável. Ao modularizar seu código, você cria blocos de construção que podem ser compostos para construir qualquer ambiente, acelerando o desenvolvimento e garantindo a consistência.