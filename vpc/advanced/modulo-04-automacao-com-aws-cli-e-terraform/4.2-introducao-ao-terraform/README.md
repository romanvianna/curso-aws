# Módulo 4.2: Introdução ao Terraform

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Pré-requisitos

*   Conhecimento básico de conceitos de nuvem (VPC, sub-redes, instâncias).
*   Familiaridade com a linha de comando.
*   AWS CLI instalada e configurada (para autenticação do Terraform).

## Objetivos

*   Entender a Infraestrutura como Código (IaC) como um paradigma fundamental para o gerenciamento de nuvem moderna.
*   Posicionar o Terraform como uma ferramenta declarativa líder para IaC, compreendendo suas vantagens sobre abordagens imperativas.
*   Aprender a sintaxe HCL (HashiCorp Configuration Language) básica para definir recursos AWS.
*   Dominar o fluxo de trabalho central do Terraform: `init`, `plan`, `apply`, `destroy`.
*   Escrever e aplicar seu primeiro template Terraform para provisionar uma VPC de forma declarativa, incluindo sub-redes e tags.
*   Compreender o papel do arquivo de estado do Terraform e sua importância.

---

## 1. O Paradigma da Infraestrutura como Código (Teoria - 60 min)

### O que é Infraestrutura como Código (IaC)?

**Infraestrutura como Código (IaC)** é uma prática de TI que codifica e gerencia a infraestrutura subjacente (redes, servidores, bancos de dados, etc.) como software. Em vez de usar o console da AWS (configuração manual e propensa a erros) ou escrever scripts imperativos (como no módulo anterior, que descrevem *como* fazer algo), você cria arquivos de definição legíveis por máquina que servem como a **fonte da verdade** para como sua infraestrutura deve ser.

Isso representa uma mudança de mentalidade fundamental:

*   **De Servidores "Animais de Estimação" (Pets) para Servidores "Gado" (Cattle):**
    *   **Pets:** Servidores que são únicos, nomeados, cuidados manualmente. Se um fica doente, você o trata e o recupera. Ambientes "pet" são difíceis de escalar e replicar.
    *   **Cattle:** Servidores que são idênticos, criados a partir de uma imagem comum, projetados para serem substituídos, não consertados. Se um fica doente, você o remove e o substitui por um novo e idêntico. A IaC é o que torna o modelo "gado" possível, garantindo que você possa recriar qualquer parte da sua infraestrutura de forma idêntica e automática.

### Abordagem Declarativa: Terraform

O **Terraform** é a ferramenta de IaC de código aberto mais popular, desenvolvida pela HashiCorp. Sua principal característica é a abordagem **declarativa**.

*   **Declarativo ("O Quê"):** Você descreve o **estado final** que deseja que sua infraestrutura tenha. Por exemplo: "Eu quero uma VPC com este CIDR, duas sub-redes (uma pública e uma privada) e um Internet Gateway."
*   **Imperativo ("Como"):** Em contraste, uma abordagem imperativa descreve os **passos** para chegar lá. Por exemplo: "Primeiro, crie a VPC. Depois, crie a primeira sub-rede. Depois, crie a segunda sub-rede. Em seguida, crie o Internet Gateway e anexe-o à VPC."

**Por que a abordagem declarativa é tão poderosa?**

*   **Gerenciamento de Estado:** O Terraform introduz um conceito crucial: o **arquivo de estado** (`terraform.tfstate`). Este arquivo JSON é um banco de dados que mapeia os recursos no seu código para os recursos reais que existem na nuvem. Ele é fundamental para o Terraform entender o estado atual da sua infraestrutura.
*   **Convergência de Estado:** Quando você executa o Terraform, ele:
    1.  Lê seu código para entender o **estado desejado**.
    2.  Lê o arquivo de estado para entender o **estado atual conhecido**.
    3.  Consulta a nuvem (via APIs da AWS) para verificar se o estado atual ainda é preciso e detectar qualquer "drift" (desvio entre o estado real e o estado desejado).
    4.  **Calcula a diferença (o "delta")** entre o desejado e o atual.
    5.  Gera um plano de execução para fazer apenas as alterações necessárias (criar, atualizar ou destruir) para que o estado atual **convirja** para o estado desejado.

Isso torna as operações idempotentes (você pode executar o mesmo código várias vezes e o resultado será o mesmo) e muito mais seguras, pois o Terraform gerencia as dependências e a ordem de criação/destruição dos recursos.

### O Fluxo de Trabalho Central do Terraform

O trabalho com o Terraform se resume a um ciclo de quatro comandos principais:

1.  `terraform init`
    *   **O que faz:** Prepara o diretório de trabalho. Ele lê seus arquivos de configuração, identifica os **provedores** (providers) necessários (ex: `aws`, `azurerm`, `google`) e os baixa do Terraform Registry. Ele também configura o **backend** onde o arquivo de estado será armazenado (por padrão, localmente).
    *   **Quando usar:** Apenas uma vez por projeto, ou sempre que você adicionar um novo provedor, módulo ou alterar a configuração do backend.

2.  `terraform plan`
    *   **O que faz:** Gera um **plano de execução**. Este é o passo mais importante para a segurança e previsibilidade. O Terraform mostra exatamente o que ele fará (quais recursos serão adicionados, alterados ou destruídos) **antes** de fazer qualquer coisa na sua conta AWS. Ele não faz nenhuma alteração real.
    *   **Quando usar:** Sempre antes de aplicar. É a sua chance de revisar e garantir que as alterações propostas são as que você espera e deseja.

3.  `terraform apply`
    *   **O que faz:** Executa as ações descritas no plano para criar, modificar ou deletar a infraestrutura real na sua conta AWS. Ele pedirá uma confirmação explícita (`yes`) antes de prosseguir, a menos que você use a flag `-auto-approve` (não recomendado para produção).
    *   **Quando usar:** Quando você estiver satisfeito com o plano e pronto para fazer as alterações na sua infraestrutura.

4.  `terraform destroy`
    *   **O que faz:** Deleta todos os recursos gerenciados pelo Terraform no seu arquivo de estado. Ele também mostrará um plano de destruição e pedirá confirmação.
    *   **Quando usar:** Para limpar ambientes de teste ou desenvolvimento. **Use com extrema cautela em ambientes de produção!**

---

## 2. Primeiro Template Terraform (Prática - 60 min)

Neste laboratório, vamos instalar o Terraform e converter nosso script imperativo (do Módulo 4.1) em um template Terraform declarativo para provisionar uma VPC básica.

### Cenário: Provisionamento de VPC para Ambiente de Desenvolvimento

Uma equipe de desenvolvimento precisa de uma VPC isolada para seus testes. Em vez de usar scripts imperativos, eles querem adotar a Infraestrutura como Código com Terraform para garantir que a VPC seja sempre provisionada de forma consistente e possa ser facilmente replicada ou modificada.

### Roteiro Prático

**Passo 1: Instalar o Terraform e Configurar a Autenticação**
1.  Siga as instruções na [página de downloads do Terraform](https://www.terraform.io/downloads.html) para instalar o executável em sua máquina (Linux, macOS, Windows).
2.  Verifique a instalação e a versão: `terraform --version`.
3.  Certifique-se de que sua AWS CLI está configurada (`aws configure`), pois o Terraform usará as mesmas credenciais para se autenticar na AWS.

**Passo 2: Criar o Projeto Terraform**
1.  Crie um novo diretório para o seu projeto Terraform: `mkdir terraform-first-vpc`
2.  Entre no diretório: `cd terraform-first-vpc`
3.  Crie um arquivo de configuração principal: `touch main.tf`

**Passo 3: Escrever o Código Terraform Declarativo**
Abra o `main.tf` e adicione o seguinte código HCL. Note como não estamos dizendo *como* criar, apenas *o que* queremos que exista. O Terraform se encarregará dos passos.

```hcl
# Bloco de configuração do Terraform para especificar o provedor AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a versão mais recente compatível
    }
  }
}

# Configuração do provedor AWS
provider "aws" {
  region = "us-east-1" # Defina a região da AWS
}

# 1. Declaração de um recurso: uma VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block = "10.200.0.0/16"

  tags = {
    Name        = "Terraform-Lab-VPC"
    Environment = "Development"
  }
}

# 2. Declaração de outro recurso: uma sub-rede pública
resource "aws_subnet" "lab_public_subnet" {
  # Referência a um atributo de outro recurso (vpc_id).
  # O Terraform entende essa dependência implicitamente e criará a VPC primeiro.
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.200.1.0/24"
  availability_zone       = "us-east-1a" # Escolha uma AZ na sua região
  map_public_ip_on_launch = true # Habilita auto-assign de IPs públicos

  tags = {
    Name = "Terraform-Lab-Public-Subnet"
  }
}

# 3. Declaração de um Internet Gateway
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name = "Terraform-Lab-IGW"
  }
}

# 4. Declaração de uma Tabela de Rotas Pública
resource "aws_route_table" "lab_public_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }

  tags = {
    Name = "Terraform-Lab-Public-RT"
  }
}

# 5. Associação da Tabela de Rotas à Sub-rede Pública
resource "aws_route_table_association" "lab_public_subnet_association" {
  subnet_id      = aws_subnet.lab_public_subnet.id
  route_table_id = aws_route_table.lab_public_rt.id
}

# Declaração de valores de saída (outputs)
# Estes valores podem ser usados por outros módulos ou para verificação.
output "vpc_id" {
  description = "The ID of the VPC created by Terraform"
  value       = aws_vpc.lab_vpc.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet created by Terraform"
  value       = aws_subnet.lab_public_subnet.id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway created by Terraform"
  value       = aws_internet_gateway.lab_igw.id
}
```

**Passo 4: Executar o Fluxo de Trabalho do Terraform**

1.  **Inicializar:**
    `terraform init`
    *   O Terraform baixará o provedor `aws` e inicializará o backend.

2.  **Planejar:**
    `terraform plan`
    *   Revise a saída. O Terraform mostrará um plano detalhado de todos os recursos que serão criados, alterados ou destruídos. Ele deve informar: `Plan: 5 to add, 0 to change, 0 to destroy.`

3.  **Aplicar:**
    `terraform apply`
    *   O Terraform mostrará o plano novamente. Confirme digitando `yes`.
    *   Aguarde a criação dos recursos. Ao final, ele exibirá as saídas definidas:
        `Outputs: vpc_id = "vpc-xxxxxxxxxxxxxxxxx"`
        `public_subnet_id = "subnet-xxxxxxxxxxxxxxxxx"`
        `internet_gateway_id = "igw-xxxxxxxxxxxxxxxxx"`
    *   Inspecione o diretório. Você verá um novo arquivo `terraform.tfstate`, que é o estado local do Terraform.

4.  **Validar:**
    *   Vá para o console da AWS VPC.
    *   Você verá a `Terraform-Lab-VPC` com a sub-rede pública, o Internet Gateway e a tabela de rotas configurada e associada corretamente.
    *   Tente lançar uma instância EC2 na sub-rede pública e verifique se ela consegue acessar a internet.

**Passo 5: Destruir a Infraestrutura**
1.  Para limpar os recursos criados, use o comando de destruição do Terraform.
    `terraform destroy`
2.  Ele mostrará um plano para destruir os 5 recursos. Confirme com `yes`.
3.  O Terraform lerá o arquivo de estado e removerá todos os recursos que ele gerencia na sua conta AWS.

Este laboratório introduz a mudança de paradigma do imperativo para o declarativo, mostrando como o Terraform simplifica o gerenciamento da infraestrutura através do seu fluxo de trabalho de `plan` e `apply` e do gerenciamento de estado.

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Gerenciamento de Estado Remoto:** Em ambientes de equipe ou produção, nunca use o estado local (`terraform.tfstate`). Configure um backend remoto (ex: S3 com DynamoDB para bloqueio de estado) para armazenar o arquivo de estado de forma segura e colaborativa.
*   **Versionamento do Código:** Mantenha seu código Terraform sob controle de versão (Git) para rastrear alterações, facilitar a colaboração e permitir reversões.
*   **Módulos:** Para infraestruturas mais complexas, utilize módulos Terraform para reutilizar blocos de código e organizar sua configuração. Isso será abordado no próximo módulo.
*   **Variáveis:** Use variáveis para tornar seu código Terraform flexível e reutilizável em diferentes ambientes (dev, staging, prod).
*   **Outputs:** Defina outputs para expor informações importantes sobre os recursos criados, que podem ser consumidas por outros módulos ou scripts.
*   **Validação:** Sempre execute `terraform validate` para verificar a sintaxe e a validade do seu código antes de planejar ou aplicar.
*   **Revisão de Planos:** Sempre revise cuidadosamente a saída de `terraform plan` antes de executar `terraform apply`. Isso é sua última linha de defesa contra alterações indesejadas.
*   **Princípio do Menor Privilégio:** As credenciais AWS usadas pelo Terraform devem ter apenas as permissões necessárias para criar, modificar e destruir os recursos definidos no seu código.
