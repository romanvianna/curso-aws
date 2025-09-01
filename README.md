# Estudos e Laboratórios de AWS

Bem-vindo ao meu repositório de estudos da AWS! Este espaço é dedicado a documentar meu aprendizado, laboratórios práticos e configurações de referência para diversos serviços e arquiteturas na nuvem da Amazon Web Services.

O objetivo é criar um guia de referência pessoal e um índice que possa ser consultado para reforçar o conhecimento e acelerar a implementação de soluções no futuro.

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

## Planos de Curso

- [Plano de Curso - AWS VPC: Do Essencial ao Avançado (8 Aulas)](./README-CURSO-ADVANCED.md)

---

## Índice de Módulos de Estudo

### Curso: VPC (Virtual Private Cloud)

#### Nível: Essential

-   **Módulo 01: Fundamentos da VPC**
    -   [1.1: O que é VPC?](./vpc/essential/modulo-01-fundamentos-da-vpc/1.1-o-que-e-vpc/README.md)
    -   [1.2: VPC Padrão](./vpc/essential/modulo-01-fundamentos-da-vpc/1.2-vpc-padrao/README.md)
    -   [1.3: Conhecendo os Componentes](./vpc/essential/modulo-01-fundamentos-da-vpc/1.3-conhecendo-os-componentes/README.md)
-   **Módulo 02: Conectividade e Segurança Básica**
    -   [2.1: Revisando Security Groups](./vpc/essential/modulo-02-conectividade-e-seguranca-basica/2.1-revisando-security-groups/README.md)
    -   [2.2: Criando as Instâncias](./vpc/essential/modulo-02-conectividade-e-seguranca-basica/2.2-criando-as-instancias/README.md)
    -   [2.3: Conhecendo ACLs](./vpc/essential/modulo-02-conectividade-e-seguranca-basica/2.3-conhecendo-acls/README.md)
-   **Módulo 03: Redes Públicas e Privadas**
    -   [3.1: Criação de uma VPC](./vpc/essential/modulo-03-redes-publicas-e-privadas/3.1-criacao-de-uma-vpc/README.md)
    -   [3.2: Usando a VPC com Instâncias](./vpc/essential/modulo-03-redes-publicas-e-privadas/3.2-usando-a-vpc-com-instancias/README.md)
    -   [3.3: Ajustando Permissões](./vpc/essential/modulo-03-redes-publicas-e-privadas/3.3-ajustando-permissoes/README.md)
-   **Módulo 04: Introdução ao Roteamento**
    -   [4.1: Tabela de Rotas Básica](./vpc/essential/modulo-04-introducao-ao-roteamento/4.1-tabela-de-rotas-basica/README.md)
    -   [4.2: Internet Gateway](./vpc/essential/modulo-04-introducao-ao-roteamento/4.2-internet-gateway/README.md)
    -   [4.3: Introdução ao AWS CLI](./vpc/essential/modulo-04-introducao-ao-roteamento/4.3-introducao-ao-aws-cli/README.md)

#### Nível: Advanced

-   **Módulo 01: Roteamento Avançado e NAT**
    -   [1.1: Internet Gateway vs. NAT](./vpc/advanced/modulo-01-roteamento-avancado-e-nat/1.1-internet-gateway-vs-nat/README.md)
    -   [1.2: Expondo a Rede Privada](./vpc/advanced/modulo-01-roteamento-avancado-e-nat/1.2-expondo-a-rede-privada/README.md)
    -   [1.3: Configurando S3](./vpc/advanced/modulo-01-roteamento-avancado-e-nat/1.3-configurando-s3/README.md)
    -   [1.4: VPC Endpoints](./vpc/advanced/modulo-01-roteamento-avancado-e-nat/1.4-vpc-endpoints/README.md)
-   **Módulo 02: Segurança Avançada**
    -   [2.1: ACLs e Security Groups Avançados](./vpc/advanced/modulo-02-seguranca-avancada/2.1-acls-e-security-groups-avancados/README.md)
    -   [2.2: Controle Granular de Acesso](./vpc/advanced/modulo-02-seguranca-avancada/2.2-controle-granular-de-acesso/README.md)
    -   [2.3: Criptografia em Trânsito](./vpc/advanced/modulo-02-seguranca-avancada/2.3-criptografia-em-transito/README.md)
-   **Módulo 03: Monitoramento e Logs**
    -   [3.1: Criando Logs](./vpc/advanced/modulo-03-monitoramento-e-logs/3.1-criando-logs/README.md)
    -   [3.2: Configurando Bastion Host](./vpc/advanced/modulo-03-monitoramento-e-logs/3.2-configurando-bastion-host/README.md)
    -   [3.3: Monitoramento com CloudWatch](./vpc/advanced/modulo-03-monitoramento-e-logs/3.3-monitoramento-com-cloudwatch/README.md)
-   **Módulo 04: Automação com AWS CLI e Terraform**
    -   [4.1: AWS CLI Avançado](./vpc/advanced/modulo-04-automacao-com-aws-cli-e-terraform/4.1-aws-cli-avancado/README.md)
    -   [4.2: Introdução ao Terraform](./vpc/advanced/modulo-04-automacao-com-aws-cli-e-terraform/4.2-introducao-ao-terraform/README.md)
    -   [4.3: Templates Terraform Avançados](./vpc/advanced/modulo-04-automacao-com-aws-cli-e-terraform/4.3-templates-terraform-avancados/README.md)

#### Nível: Plus

-   **Módulo 01: Conectividade Multi-VPC**
    -   [1.1: VPC Peering](./vpc/plus/modulo-01-conectividade-multi-vpc/1.1-vpc-peering/README.md)
    -   [1.2: Transit Gateway](./vpc/plus/modulo-01-conectividade-multi-vpc/1.2-transit-gateway/README.md)
    -   [1.3: AWS Direct Connect](./vpc/plus/modulo-01-conectividade-multi-vpc/1.3-aws-direct-connect/README.md)
    -   [1.4: Site-to-Site VPN](./vpc/plus/modulo-01-conectividade-multi-vpc/1.4-site-to-site-vpn/README.md)
-   **Módulo 02: Arquiteturas Enterprise**
    -   [2.1: Multi-Account Strategy](./vpc/plus/modulo-02-arquiteturas-enterprise/2.1-multi-account-strategy/README.md)
    -   [2.2: Shared Services VPC](./vpc/plus/modulo-02-arquiteturas-enterprise/2.2-shared-services-vpc/README.md)
    -   [2.3: Disaster Recovery](./vpc/plus/modulo-02-arquiteturas-enterprise/2.3-disaster-recovery/README.md)
-   **Módulo 03: Segurança Enterprise**
    -   [3.1: Network Firewall](./vpc/plus/modulo-03-seguranca-enterprise/3.1-network-firewall/README.md)
    -   [3.2: GuardDuty e Security Hub](./vpc/plus/modulo-03-seguranca-enterprise/3.2-guardduty-e-security-hub/README.md)
    -   [3.3: Compliance e Auditoria](./vpc/plus/modulo-03-seguranca-enterprise/3.3-compliance-e-auditoria/README.md)
-   **Módulo 04: Otimização e Troubleshooting**
    -   [4.1: Performance Tuning](./vpc/plus/modulo-04-otimizacao-e-troubleshooting/4.1-performance-tuning/README.md)
    -   [4.2: Cost Optimization](./vpc/plus/modulo-04-otimizacao-e-troubleshooting/4.2-cost-optimization/README.md)
    -   [4.3: Troubleshooting Avançado](./vpc/plus/modulo-04-otimizacao-e-troubleshooting/4.3-troubleshooting-avancado/README.md)
    -   [4.4: Automation at Scale](./vpc/plus/modulo-04-otimizacao-e-troubleshooting/4.4-automation-at-scale/README.md)

---

## Próximos Cursos

*(Esta seção será atualizada à medida que novos módulos de estudo forem adicionados.)*