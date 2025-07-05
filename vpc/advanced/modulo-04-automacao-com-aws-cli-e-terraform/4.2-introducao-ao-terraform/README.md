# Módulo 4.2: Introdução ao Terraform

**Tempo de Aula:** 60 minutos de teoria, 60 minutos de prática

## Objetivos

- Entender a Infraestrutura como Código (IaC) como um paradigma para o gerenciamento de nuvem.
- Posicionar o Terraform como uma ferramenta declarativa para IaC.
- Aprender a sintaxe HCL e o fluxo de trabalho central do Terraform: `init`, `plan`, `apply`.
- Escrever e aplicar seu primeiro template Terraform para provisionar uma VPC de forma declarativa.

---

## 1. O Paradigma da Infraestrutura como Código (Teoria - 60 min)

### O que é Infraestrutura como Código (IaC)?

**Infraestrutura como Código (IaC)** é uma prática de TI que codifica e gerencia a infraestrutura subjacente como software. Em vez de usar o console da AWS (configuração manual) ou escrever scripts imperativos (como no módulo anterior), você cria arquivos de definição legíveis por máquina que servem como a **fonte da verdade** para como sua infraestrutura deve ser.

Isso representa uma mudança de mentalidade fundamental:

-   **De Servidores "Animais de Estimação" (Pets) para Servidores "Gado" (Cattle):**
    -   **Pets:** Servidores que são únicos, nomeados, cuidados manualmente. Se um fica doente, você o trata e o recupera.
    -   **Cattle:** Servidores que são idênticos, criados a partir de uma imagem comum, projetados para serem substituídos, não consertados. Se um fica doente, você o remove e o substitui por um novo e idêntico.
    -   A IaC é o que torna o modelo "gado" possível, garantindo que você possa recriar qualquer parte da sua infraestrutura de forma idêntica e automática.

### Abordagem Declarativa: Terraform

O **Terraform** é a ferramenta de IaC de código aberto mais popular. Sua principal característica é a abordagem **declarativa**.

-   **Declarativo ("O Quê"):** Você descreve o **estado final** que deseja. "Eu quero uma VPC com este CIDR e duas sub-redes".
-   **Imperativo ("Como"):** Você descreve os **passos** para chegar lá. "Primeiro, crie a VPC. Depois, crie a primeira sub-rede. Depois, crie a segunda sub-rede".

**Por que a abordagem declarativa é tão poderosa?**

-   **Gerenciamento de Estado:** O Terraform introduz um conceito crucial: o **arquivo de estado** (`terraform.tfstate`). Este arquivo JSON é um banco de dados que mapeia os recursos no seu código para os recursos reais que existem na nuvem. 
-   **Convergência de Estado:** Quando você executa o Terraform, ele:
    1.  Lê seu código para entender o **estado desejado**.
    2.  Lê o arquivo de estado para entender o **estado atual**.
    3.  Consulta a nuvem para verificar se o estado atual ainda é preciso.
    4.  **Calcula a diferença (o "delta")** entre o desejado e o atual.
    5.  Gera um plano de execução para fazer apenas as alterações necessárias (criar, atualizar ou destruir) para que o estado atual **convirja** para o estado desejado.

Isso torna as operações idempotentes (você pode executar o mesmo código várias vezes e o resultado será o mesmo) e muito mais seguras.

### O Fluxo de Trabalho Central do Terraform

O trabalho com o Terraform se resume a um ciclo de três comandos:

1.  `terraform init`
    -   **O que faz:** Prepara o diretório de trabalho. Ele lê seus arquivos de configuração, identifica os **provedores** (providers) necessários (ex: `aws`) e os baixa do Terraform Registry. Ele também configura o **backend** onde o arquivo de estado será armazenado.
    -   **Quando usar:** Apenas uma vez por projeto, ou sempre que você adicionar um novo provedor ou módulo.

2.  `terraform plan`
    -   **O que faz:** Gera um **plano de execução**. Este é o passo mais importante para a segurança. O Terraform mostra exatamente o que ele fará **antes** de fazer qualquer coisa. Você verá uma lista de recursos a serem adicionados, alterados ou destruídos.
    -   **Quando usar:** Sempre antes de aplicar. É a sua chance de revisar e garantir que as alterações são as que você espera.

3.  `terraform apply`
    -   **O que faz:** Executa as ações descritas no plano para criar, modificar ou deletar a infraestrutura real. Ele pedirá uma confirmação explícita (`yes`) antes de prosseguir.
    -   **Quando usar:** Quando você estiver satisfeito com o plano e pronto para fazer as alterações.

---

## 2. Primeiro Template Terraform (Prática - 60 min)

Neste laboratório, vamos instalar o Terraform e converter nosso script imperativo em um template Terraform declarativo para provisionar uma VPC.

### Roteiro Prático

**Passo 1: Instalar o Terraform e Configurar a Autenticação**
1.  Siga as instruções na [página de downloads do Terraform](https://www.terraform.io/downloads.html) para instalar o executável em sua máquina.
2.  Verifique a instalação: `terraform --version`.
3.  Certifique-se de que sua AWS CLI está configurada (`aws configure`), pois o Terraform usará as mesmas credenciais.

**Passo 2: Criar o Projeto Terraform**
1.  Crie um novo diretório: `mkdir terraform-declarative-lab`
2.  Entre no diretório: `cd terraform-declarative-lab`
3.  Crie um arquivo de configuração principal: `touch main.tf`

**Passo 3: Escrever o Código Terraform Declarativo**
Abra o `main.tf` e adicione o seguinte código HCL. Note como não estamos dizendo *como* criar, apenas *o que* queremos que exista.

```hcl
# Bloco de configuração do Terraform para especificar o provedor
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configuração do provedor AWS
provider "aws" {
  region = "us-east-1"
}

# Declaração de um recurso: uma VPC
resource "aws_vpc" "main" {
  cidr_block = "10.200.0.0/16"

  tags = {
    Name = "Terraform-VPC"
  }
}

# Declaração de outro recurso: uma sub-rede
resource "aws_subnet" "public" {
  # Referência a um atributo de outro recurso.
  # O Terraform entende essa dependência implicitamente.
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.200.1.0/24"

  tags = {
    Name = "Terraform-Public-Subnet"
  }
}

# Declaração de um valor de saída
output "vpc_id" {
  description = "The ID of the VPC created by Terraform"
  value       = aws_vpc.main.id
}
```

**Passo 4: Executar o Fluxo de Trabalho do Terraform**

1.  **Inicializar:**
    `terraform init`
    -   O Terraform baixará o provedor `aws`.

2.  **Planejar:**
    `terraform plan`
    -   Revise a saída. O Terraform deve informar: `Plan: 2 to add, 0 to change, 0 to destroy.`

3.  **Aplicar:**
    `terraform apply`
    -   O Terraform mostrará o plano novamente. Confirme digitando `yes`.
    -   Aguarde a criação dos recursos. Ao final, ele exibirá a saída definida:
        `Outputs: vpc_id = "vpc-xxxxxxxxxxxxxxxxx"`
    -   Inspecione o diretório. Você verá um novo arquivo `terraform.tfstate`.

4.  **Validar:**
    -   Vá para o console da AWS VPC. Você verá a `Terraform-VPC` e a sub-rede associada.

**Passo 5: Destruir a Infraestrutura**
1.  Para limpar, use o comando de destruição do Terraform.
    `terraform destroy`
2.  Ele mostrará um plano para destruir os 2 recursos. Confirme com `yes`.
3.  O Terraform lerá o arquivo de estado e removerá todos os recursos que ele gerencia.

Este laboratório introduz a mudança de paradigma do imperativo para o declarativo, mostrando como o Terraform simplifica o gerenciamento da infraestrutura através do seu fluxo de trabalho de `plan` e `apply` e do gerenciamento de estado.