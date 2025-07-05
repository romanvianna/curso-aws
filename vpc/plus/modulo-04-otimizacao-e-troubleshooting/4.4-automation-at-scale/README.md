# Módulo 4.4: Automação em Escala com GitOps

**Tempo de Aula:** 90 minutos de teoria, 90 minutos de prática

## Objetivos

- Entender o GitOps como um modelo operacional para o gerenciamento de infraestrutura e aplicações.
- Analisar os componentes de um pipeline de CI/CD para Infraestrutura como Código (IaC).
- Aprender como ferramentas como o GitHub Actions podem ser usadas para automatizar o fluxo de `plan` e `apply` do Terraform.
- Projetar e discutir a implementação de um pipeline de GitOps para gerenciar a infraestrutura da VPC.

---

## 1. O Modelo Operacional GitOps (Teoria - 90 min)

Já estabelecemos que a Infraestrutura como Código (IaC), usando ferramentas declarativas como o Terraform, é a maneira moderna de gerenciar a nuvem. O **GitOps** é um modelo operacional que leva essa ideia um passo adiante. Ele aplica as práticas de desenvolvimento de software, como controle de versão, colaboração, CI/CD e automação, ao gerenciamento da infraestrutura.

O princípio central do GitOps é:

**O repositório Git é a ÚNICA fonte da verdade.**

Qualquer alteração na infraestrutura (criar uma VPC, mudar uma regra de firewall, implantar uma nova versão de uma aplicação) deve ser feita através de uma alteração no repositório Git. Ninguém, nem mesmo um administrador sênior, deve fazer alterações manuais no console da AWS.

### Por que o GitOps é tão poderoso?

-   **Auditabilidade Total:** O histórico do Git se torna um log de auditoria perfeito e imutável de cada alteração já feita na sua infraestrutura. Você sabe quem fez a alteração, quando, e pode ver exatamente o que mudou.
-   **Revisão por Pares (Pull/Merge Requests):** Toda alteração na infraestrutura passa por um processo de revisão por pares. Um desenvolvedor propõe uma alteração através de um Pull Request (PR). Outros membros da equipe podem revisar a alteração, fazer comentários e, finalmente, aprová-la. Isso melhora a qualidade e a segurança, evitando erros antes que eles cheguem à produção.
-   **Consistência e Repetibilidade:** Como o Git é a fonte da verdade, você pode recriar seu ambiente do zero a qualquer momento, com a certeza de que ele será idêntico.
-   **Recuperação Rápida:** Se uma alteração causar um problema, a recuperação é tão simples quanto reverter o commit no Git (`git revert`). O pipeline de automação então automaticamente reverterá a infraestrutura para o último estado bom conhecido.

### Componentes de um Pipeline de CI/CD para IaC

Um pipeline de GitOps para gerenciar sua infraestrutura Terraform normalmente consiste nos seguintes componentes e etapas:

1.  **Sistema de Controle de Versão (ex: GitHub, GitLab):**
    -   Onde seu código Terraform vive. É a fonte da verdade.

2.  **Servidor de CI/CD (ex: GitHub Actions, Jenkins, GitLab CI):**
    -   O motor de automação que reage a eventos no repositório Git.

3.  **O Fluxo de Trabalho do Pull Request (PR):**
    -   **Passo 1: O Desenvolvedor Cria um PR:** Um engenheiro faz uma alteração no código Terraform em um branch e abre um Pull Request para o branch principal (`main`).
    -   **Passo 2: Automação no PR (CI - Integração Contínua):** A abertura do PR aciona automaticamente um pipeline que executa uma série de verificações de qualidade:
        -   `terraform init`: Verifica se o código é inicializável.
        -   `terraform validate`: Verifica se a sintaxe do código está correta.
        -   `terraform fmt -check`: Verifica se o código está formatado corretamente.
        -   **`terraform plan`:** Este é o passo mais importante. O pipeline executa um `plan` e **publica o resultado como um comentário no PR**. Isso permite que os revisores vejam exatamente qual será o impacto da alteração na infraestrutura.
        -   *Opcional:* Ferramentas de análise de segurança estática (ex: `tfsec`, `checkov`) para procurar por configurações inseguras no código.
    -   **Passo 3: Revisão Humana:** Os colegas de equipe revisam o código e o plano do Terraform. Se tudo estiver correto, eles aprovam o PR.

4.  **O Fluxo de Trabalho do Merge (CD - Entrega/Implantação Contínua):**
    -   **Passo 4: O Merge Acontece:** O PR aprovado é mesclado no branch `main`.
    -   **Passo 5: Automação no Merge (CD):** O merge no `main` aciona um segundo pipeline, o pipeline de implantação.
        -   Este pipeline executa novamente o `init` e o `plan` (como uma última verificação).
        -   Se o plano for bem-sucedido, ele executa o **`terraform apply -auto-approve`**. Este comando aplica as alterações à infraestrutura real na AWS.

Este ciclo fechado garante que cada alteração seja validada, revisada e aplicada de forma automática e segura, tornando o processo de gerenciamento de infraestrutura robusto e escalável.

---

## 2. Projeto de um Pipeline de GitOps (Prática - 90 min)

Neste laboratório, não vamos implementar um pipeline completo, pois isso requer a configuração de um repositório Git e um sistema de CI/CD. Em vez disso, vamos **projetar o fluxo de trabalho** e escrever o arquivo de configuração do **GitHub Actions** que implementaria nosso pipeline de GitOps para o código Terraform da nossa VPC.

### Cenário

-   Temos nosso projeto Terraform que define nossa `Lab-VPC` em um repositório no GitHub.
-   Queremos automatizar o processo de `plan` nos Pull Requests e `apply` nos merges para o branch `main`.

### Roteiro Prático

**Passo 1: Estrutura do Repositório**
1.  Imagine que nosso projeto `terraform-declarative-lab` está em um repositório no GitHub.
2.  Dentro do projeto, criaríamos um diretório `.github/workflows/`.
3.  Dentro deste diretório, criaríamos nosso arquivo de definição do pipeline: `terraform.yml`.

**Passo 2: Projetar o Pipeline do GitHub Actions (`terraform.yml`)**

Vamos escrever o conteúdo do arquivo `terraform.yml`. Este arquivo define os gatilhos e os passos para nossos pipelines de CI e CD.

```yaml
# .github/workflows/terraform.yml

name: 'Terraform CI/CD'

# Gatilhos do pipeline
on:
  push:
    branches:
      - main  # Aciona o pipeline de 'apply' no merge/push para o main
  pull_request:
    branches:
      - main  # Aciona o pipeline de 'plan' na abertura de PR para o main

jobs:
  terraform:
    name: 'Terraform'
    runs-on: ubuntu-latest

    steps:
      # Passo 1: Fazer o checkout do código do repositório
      - name: Checkout
        uses: actions/checkout@v2

      # Passo 2: Configurar as credenciais da AWS
      # Usa o OIDC para obter credenciais temporárias de forma segura, sem armazenar chaves de acesso
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/GitHubActions-Terraform-Role # Uma role IAM que o GitHub pode assumir
          aws-region: ${{ secrets.AWS_REGION }}

      # Passo 3: Configurar o Terraform
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1

      # Passo 4: Inicializar o Terraform
      - name: Terraform Init
        run: terraform init

      # Passo 5: Gerar o Plano (para PRs)
      # Este passo só executa em eventos de pull_request
      - name: Terraform Plan
        if: github.event_name == 'pull_request'
        run: terraform plan -no-color
        # Em um pipeline real, usaríamos uma action para postar o plano no PR

      # Passo 6: Aplicar as Mudanças (para o branch main)
      # Este passo só executa em pushes para o branch 'main'
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve
```

**Passo 3: Análise do Pipeline Projetado**

-   **Gatilhos (`on`):** O pipeline é acionado em duas condições: um `push` para o branch `main` (que acontece quando um PR é mesclado) ou a criação de um `pull_request` direcionado ao `main`.
-   **Credenciais Seguras:** O pipeline não armazena segredos de longa duração. Ele usa o padrão OIDC (OpenID Connect) para que o GitHub Actions possa assumir uma IAM Role na AWS e obter credenciais temporárias e de curta duração para executar o Terraform.
-   **Lógica Condicional (`if`):**
    -   O passo `Terraform Plan` só é executado se o evento que acionou o pipeline for um `pull_request`. Isso garante que o plano seja gerado para revisão.
    -   O passo `Terraform Apply` só é executado se o evento for um `push` para o branch `main`. Isso garante que as implantações só aconteçam após a revisão e o merge, seguindo o fluxo GitOps.

**Passo 4: Discussão do Fluxo de Trabalho Completo**

1.  **Desenvolvedor:**
    -   `git checkout -b feature/add-private-subnet`
    -   Edita os arquivos `.tf` para adicionar uma nova sub-rede privada.
    -   `git commit -m "feat: add private subnet"`
    -   `git push origin feature/add-private-subnet`
    -   Abre um Pull Request no GitHub.

2.  **GitHub Actions (Pipeline de CI):**
    -   O pipeline é acionado.
    -   Ele executa `init`, `validate` e `plan`.
    -   Um bot posta o resultado do `terraform plan` como um comentário no PR: "Plano: 1 para adicionar, 0 para alterar, 0 para destruir."

3.  **Revisores:**
    -   Analisam o código e o plano. Eles veem que a alteração é segura e corresponde à intenção.
    -   Aprovam o PR.

4.  **Desenvolvedor:**
    -   Mescla o PR no branch `main`.

5.  **GitHub Actions (Pipeline de CD):**
    -   O merge aciona o pipeline novamente.
    -   Desta vez, a condição `if: github.ref == 'refs/heads/main'` é verdadeira.
    -   O pipeline executa `terraform apply -auto-approve`.
    -   A nova sub-rede privada é criada na AWS.

Este projeto, embora teórico, descreve a arquitetura e o fluxo de trabalho de um sistema de automação de infraestrutura moderno e robusto, que é o padrão da indústria para gerenciar a nuvem em escala de forma segura e eficiente.
