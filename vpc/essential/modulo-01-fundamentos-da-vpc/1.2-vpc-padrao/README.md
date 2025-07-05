# Módulo 1.2: VPC Padrão (Default VPC)

**Tempo de Aula:** 30 minutos de teoria, 30 minutos de prática

## 1. Conceitos Fundamentais (Teoria Aprofundada)

### O Princípio da Menor Surpresa e a Experiência do Usuário
A VPC Padrão existe por uma razão fundamental: fornecer uma **experiência de usuário com a menor surpresa possível** para quem está começando na AWS. Um novo usuário espera poder lançar uma máquina virtual e acessá-la, de forma semelhante a outros provedores de nuvem ou plataformas de virtualização. Forçá-lo a entender subnetting, roteamento e gateways antes de poder lançar sua primeira instância criaria uma barreira de entrada significativa.

Para alcançar essa simplicidade, a VPC Padrão é projetada como uma **rede "flat" e pública**. 
-   **Rede Flat:** Não há segmentação de rede inerente. Todos os recursos lançados em qualquer uma das sub-redes padrão podem se comunicar entre si por padrão (através da rota `local` na tabela de rotas principal), como se estivessem conectados ao mesmo switch de rede.
-   **Pública por Padrão:** A combinação de um Internet Gateway anexado, uma tabela de rotas que direciona todo o tráfego não local (`0.0.0.0/0`) para esse gateway, e a atribuição automática de IPs públicos a novas instâncias garante que qualquer recurso lançado seja imediatamente acessível a partir da internet e possa acessar a internet.

Essa configuração é uma decisão de design deliberada que prioriza a **facilidade de uso** em detrimento da **segurança e do isolamento**. É uma "rampa de acesso" para a nuvem.

## 2. Arquitetura e Casos de Uso

### Cenário Simples: Hospedando um Blog Pessoal
Um desenvolvedor quer hospedar um blog WordPress simples. A arquitetura é um monólito: um único servidor EC2 rodando o servidor web (Apache/Nginx), o PHP e o banco de dados (MySQL) na mesma máquina.

-   **Implementação:** Lançar esta instância na VPC Padrão é uma solução perfeitamente aceitável. O desenvolvedor obtém um IP público instantaneamente, pode apontar seu domínio para ele e instalar o WordPress. Ele pode então usar o Security Group padrão para permitir tráfego nas portas 80/443 e restringir o SSH ao seu IP.
-   **Justificativa:** O risco de segurança é baixo, e a sobrecarga de gerenciar uma rede complexa para uma única instância seria desnecessária. A VPC Padrão atende perfeitamente a essa necessidade de simplicidade.

### Cenário Corporativo Robusto: Política de "Terra Arrasada"
Uma empresa de tecnologia financeira, regulamentada, adota uma política de segurança de "terra arrasada" para novas contas AWS. O CISO (Chief Information Security Officer) determina que o risco de um desenvolvedor lançar acidentalmente um recurso com dados sensíveis em um ambiente público é inaceitável.

-   **Implementação:** Um script de automação, acionado na criação de qualquer nova conta AWS na organização, é executado. Este script usa a AWS CLI ou um SDK para:
    1.  Identificar a VPC Padrão em cada região.
    2.  Identificar e desanexar o Internet Gateway da VPC Padrão.
    3.  Deletar o Internet Gateway.
    4.  Deletar as sub-redes padrão.
    5.  Finalmente, deletar a própria VPC Padrão.
    Isso deixa a conta como uma "tela em branco", forçando todas as equipes a provisionar infraestrutura de rede através de templates Terraform aprovados e em VPCs Customizadas.
-   **Justificativa:** Para esta organização, a segurança e a governança explícita superam em muito a conveniência. A VPC Padrão é vista como uma vulnerabilidade de configuração que deve ser eliminada proativamente para garantir que nenhuma carga de trabalho possa ser exposta à internet sem passar por um processo de design e aprovação de arquitetura.

## 3. Melhores Práticas (AWS Well-Architected)

-   **Segurança:** A melhor prática é **não usar a VPC Padrão para nenhuma carga de trabalho de produção**. Seu design inerentemente público não é adequado para aplicações que exigem isolamento.
-   **Excelência Operacional:** Se você decidir que sua organização não deve usar a VPC Padrão, automatize sua exclusão na criação de novas contas para garantir a aplicação consistente da política.
-   **Confiabilidade:** A VPC Padrão, como qualquer VPC, é altamente confiável. No entanto, a falta de segmentação pode significar que um erro de configuração em um recurso pode impactar a conectividade de outros de forma inesperada.
-   **Otimização de Custos:** Embora a VPC seja gratuita, lançar recursos nela que se comunicam através de AZs incorrerá em custos de transferência de dados. A falta de um design intencional pode levar a custos inesperados.

## 4. Guia Prático (Laboratório)

O laboratório se concentra em uma dissecação forense da VPC Padrão. O objetivo é que o aluno possa responder a perguntas específicas sobre sua configuração, validando o conhecimento teórico:
-   Qual é o bloco CIDR da VPC Padrão?
-   Qual é a regra na tabela de rotas que a torna pública?
-   Qual configuração na sub-rede garante que uma nova instância receba um IP público?
-   Quais são as regras padrão da Network ACL e do Security Group e por que elas são consideradas permissivas?
Este exercício prático solidifica a compreensão de por que a VPC Padrão funciona da maneira que funciona e por que ela não é ideal para ambientes seguros.
