# Módulo 1.2: VPC Padrão (Default VPC)

**Tempo de Aula:** 30 minutos de teoria, 30 minutos de prática

## Pré-requisitos

*   Conhecimento dos conceitos fundamentais de VPC e seus componentes (Módulo 1.1).
*   Familiaridade com o console da AWS.

## Objetivos

*   Compreender o propósito e a arquitetura da VPC Padrão (Default VPC) criada automaticamente pela AWS.
*   Analisar as configurações padrão da Default VPC, incluindo sub-redes, Internet Gateway, tabelas de rotas, Network ACLs e Security Groups.
*   Identificar as vantagens e desvantagens da Default VPC para diferentes casos de uso.
*   Discutir cenários de uso apropriados e inapropriados para a Default VPC em ambientes de desenvolvimento e produção.
*   Realizar uma inspeção prática da Default VPC no console da AWS.

---

## 1. Conceitos Fundamentais: O Princípio da Menor Surpresa (Teoria - 30 min)

A VPC Padrão existe por uma razão fundamental: fornecer uma **experiência de usuário com a menor surpresa possível** para quem está começando na AWS. Um novo usuário espera poder lançar uma máquina virtual e acessá-la, de forma semelhante a outros provedores de nuvem ou plataformas de virtualização. Forçá-lo a entender subnetting, roteamento e gateways antes de poder lançar sua primeira instância criaria uma barreira de entrada significativa.

Para alcançar essa simplicidade, a VPC Padrão é projetada como uma **rede "flat" e pública**.

*   **Rede Flat:** Não há segmentação de rede inerente. Todos os recursos lançados em qualquer uma das sub-redes padrão podem se comunicar entre si por padrão (através da rota `local` na tabela de rotas principal), como se estivessem conectados ao mesmo switch de rede.
*   **Pública por Padrão:** A combinação de um Internet Gateway anexado, uma tabela de rotas que direciona todo o tráfego não local (`0.0.0.0/0`) para esse gateway, e a atribuição automática de IPs públicos a novas instâncias garante que qualquer recurso lançado seja imediatamente acessível a partir da internet e possa acessar a internet.

Essa configuração é uma decisão de design deliberada que prioriza a **facilidade de uso** em detrimento da **segurança e do isolamento**. É uma "rampa de acesso" para a nuvem, permitindo que os usuários comecem a usar os serviços rapidamente.

## 2. Arquitetura e Casos de Uso: Default VPC em Cenários Reais

### Cenário Simples: Hospedando um Blog Pessoal ou Protótipo

*   **Descrição:** Um desenvolvedor quer hospedar um blog WordPress simples ou um protótipo de aplicação. A arquitetura é um monólito: um único servidor EC2 rodando o servidor web (Apache/Nginx), o PHP e o banco de dados (MySQL) na mesma máquina.
*   **Implementação:** Lançar esta instância na VPC Padrão é uma solução perfeitamente aceitável. O desenvolvedor obtém um IP público instantaneamente, pode apontar seu domínio para ele e instalar o WordPress. Ele pode então usar o Security Group padrão para permitir tráfego nas portas 80/443 e restringir o SSH ao seu IP.
*   **Justificativa:** O risco de segurança é baixo, e a sobrecarga de gerenciar uma rede complexa para uma única instância seria desnecessária. A VPC Padrão atende perfeitamente a essa necessidade de simplicidade e agilidade para casos de uso não críticos.

### Cenário Corporativo Robusto: Política de "Terra Arrasada" (Proibição da Default VPC)

*   **Descrição:** Uma empresa de tecnologia financeira, regulamentada, adota uma política de segurança de "terra arrasada" para novas contas AWS. O CISO (Chief Information Security Officer) determina que o risco de um desenvolvedor lançar acidentalmente um recurso com dados sensíveis em um ambiente público é inaceitável.
*   **Implementação:** Um script de automação, acionado na criação de qualquer nova conta AWS na organização (via AWS Organizations), é executado. Este script usa a AWS CLI ou um SDK para:
    1.  Identificar a VPC Padrão em cada região.
    2.  Identificar e desanexar o Internet Gateway da VPC Padrão.
    3.  Deletar o Internet Gateway.
    4.  Deletar as sub-redes padrão.
    5.  Finalmente, deletar a própria VPC Padrão.
    Isso deixa a conta como uma "tela em branco", forçando todas as equipes a provisionar infraestrutura de rede através de templates Terraform ou CloudFormation aprovados e em VPCs Customizadas, que seguem os padrões de segurança e conformidade da empresa.
*   **Justificativa:** Para esta organização, a segurança e a governança explícita superam em muito a conveniência. A VPC Padrão é vista como uma vulnerabilidade de configuração que deve ser eliminada proativamente para garantir que nenhuma carga de trabalho possa ser exposta à internet sem passar por um processo de design e aprovação de arquitetura.

## 3. Guia Prático (Laboratório - 30 min)

O laboratório se concentra em uma dissecação forense da VPC Padrão. O objetivo é que o aluno possa responder a perguntas específicas sobre sua configuração, validando o conhecimento teórico e entendendo por que a Default VPC não é ideal para ambientes seguros.

**Roteiro:**
1.  **Acessar o Console VPC:** Navegue até o console da AWS e selecione o serviço **VPC**.
2.  **Identificar a Default VPC:** No painel de navegação esquerdo, clique em **"Your VPCs"**. Identifique a VPC que tem a coluna "Default VPC" marcada como "Yes". Anote seu ID e bloco CIDR.
3.  **Explorar Sub-redes:** Clique em **"Subnets"**. Filtre pelas sub-redes da sua Default VPC. Observe que há uma sub-rede em cada Zona de Disponibilidade da região. Para cada sub-rede, verifique a configuração "Auto-assign public IPv4 address" (deve estar habilitada).
4.  **Inspecionar Internet Gateway:** Clique em **"Internet Gateways"**. Identifique o IGW anexado à sua Default VPC. Observe que ele é o alvo de uma rota padrão.
5.  **Analisar Tabelas de Rotas:** Clique em **"Route Tables"**. Identifique a tabela de rotas principal da sua Default VPC (marcada como "Main: Yes"). Clique nela e vá para a aba **"Routes"**. Observe a rota `0.0.0.0/0` apontando para o Internet Gateway. Esta é a rota que torna a VPC "pública".
6.  **Verificar Network ACLs:** Clique em **"Network ACLs"**. Identifique a NACL padrão da sua Default VPC. Observe suas regras de entrada e saída (geralmente `ALLOW ALL` com regras de negação implícitas). Discuta por que ela é considerada permissiva.
7.  **Examinar Security Groups:** Clique em **"Security Groups"**. Identifique o Security Group padrão da sua Default VPC. Observe suas regras de entrada e saída (geralmente `ALLOW ALL` para tráfego de saída e `ALLOW ALL` de entrada do próprio SG). Discuta por que ele é considerado permissivo.

**Discussão Pós-Laboratório:**
*   Qual é o bloco CIDR da VPC Padrão na sua conta?
*   Qual regra na tabela de rotas a torna pública?
*   Qual configuração na sub-rede garante que uma nova instância receba um IP público?
*   Quais são as regras padrão da Network ACL e do Security Group e por que elas são consideradas permissivas?
*   Com base nesta inspeção, por que a Default VPC não é recomendada para ambientes de produção?

---

## Melhores Práticas e Dicas (Tips and Tricks)

*   **Evite a Default VPC para Produção:** A regra de ouro é **nunca usar a Default VPC para cargas de trabalho de produção ou que lidam com dados sensíveis**. Seu design inerentemente público e a falta de segmentação granular a tornam inadequada para a maioria dos requisitos de segurança e conformidade.
*   **Crie VPCs Customizadas:** Para qualquer ambiente que não seja um sandbox de desenvolvimento ou prototipagem muito simples, sempre crie uma VPC customizada. Isso lhe dá controle total sobre o endereçamento IP, sub-redes, roteamento e segurança.
*   **Automatize a Exclusão da Default VPC:** Em ambientes corporativos, considere automatizar a exclusão da Default VPC em novas contas AWS. Isso garante que todas as equipes sejam forçadas a usar VPCs customizadas e padronizadas.
*   **Entenda as Implicações de Custo:** Embora a VPC seja gratuita, o tráfego entre Zonas de Disponibilidade (AZs) dentro da mesma VPC incorre em custos de transferência de dados. Um design de rede não otimizado na Default VPC pode levar a custos inesperados.
*   **Segurança em Camadas:** Mesmo em uma Default VPC, utilize Security Groups para controlar o acesso às suas instâncias. Eles são a primeira linha de defesa em nível de instância.
*   **Monitoramento:** Habilite VPC Flow Logs e CloudTrail para monitorar o tráfego e as atividades na sua Default VPC, mesmo que seja apenas para fins de auditoria e aprendizado.