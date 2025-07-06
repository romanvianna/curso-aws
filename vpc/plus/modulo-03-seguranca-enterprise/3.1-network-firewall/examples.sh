#!/bin/bash

# --- Exemplo de comandos AWS CLI para configurar AWS Network Firewall ---

# Cenário: Este script demonstra a criação de uma VPC com sub-redes dedicadas
# para aplicação, firewall e acesso público. Em seguida, configura um AWS Network Firewall
# para filtrar o tráfego de saída, permitindo acesso a domínios específicos e bloqueando outros.

set -e # Encerra o script imediatamente se um comando falhar

# --- Definição de Variáveis ---
export AWS_REGION="us-east-1" # Defina a região da AWS
FW_VPC_NAME="FW-Lab-VPC-$(date +%s)"
FW_VPC_CIDR="10.40.0.0/16"
APP_SUBNET_CIDR="10.40.1.0/24"
FIREWALL_SUBNET_CIDR="10.40.2.0/24"
PUBLIC_SUBNET_CIDR="10.40.3.0/24"
AVAILABILITY_ZONE="us-east-1a" # Escolha uma AZ na sua região

KEY_PAIR_NAME="my-ec2-key" # Substitua pelo nome do seu Key Pair
AMI_ID="ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (us-east-1)
MY_LOCAL_IP="203.0.113.10/32" # Substitua pelo seu IP público

echo "INFO: Iniciando a configuração do AWS Network Firewall..."

# --- 1. Criar a VPC e Sub-redes ---
echo "INFO: Criando FW-VPC..."
FW_VPC_ID=$(aws ec2 create-vpc \
  --cidr-block ${FW_VPC_CIDR} \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${FW_VPC_NAME}}]" \
  --query 'Vpc.VpcId' \
  --output text)

APP_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${FW_VPC_ID} \
  --cidr-block ${APP_SUBNET_CIDR} \
  --availability-zone ${AVAILABILITY_ZONE} \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${FW_VPC_NAME}-App-Subnet}]" \
  --query 'Subnet.SubnetId' \
  --output text)

FIREWALL_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${FW_VPC_ID} \
  --cidr-block ${FIREWALL_SUBNET_CIDR} \
  --availability-zone ${AVAILABILITY_ZONE} \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${FW_VPC_NAME}-Firewall-Subnet}]" \
  --query 'Subnet.SubnetId' \
  --output text)

PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${FW_VPC_ID} \
  --cidr-block ${PUBLIC_SUBNET_CIDR} \
  --availability-zone ${AVAILABILITY_ZONE} \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${FW_VPC_NAME}-Public-Subnet}]" \
  --query 'Subnet.SubnetId' \
  --output text)

echo "SUCCESS: VPC e sub-redes criadas."

# --- 2. Configurar o Acesso à Internet (IGW e NAT Gateway) ---
echo "INFO: Configurando IGW e NAT Gateway..."
FW_IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${FW_VPC_NAME}-IGW}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)
aws ec2 attach-internet-gateway --vpc-id ${FW_VPC_ID} --internet-gateway-id ${FW_IGW_ID}

FW_NAT_EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
FW_NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id ${PUBLIC_SUBNET_ID} \
  --allocation-id ${FW_NAT_EIP_ALLOC_ID} \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=${FW_VPC_NAME}-NAT-GW}]" \
  --query 'NatGateway.NatGatewayId' \
  --output text)
aws ec2 wait nat-gateway-available --nat-gateway-ids ${FW_NAT_GW_ID}

FW_PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id ${FW_VPC_ID} \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${FW_VPC_NAME}-Public-RT}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
aws ec2 create-route --route-table-id ${FW_PUBLIC_RT_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${FW_IGW_ID} > /dev/null
aws ec2 associate-route-table --subnet-id ${PUBLIC_SUBNET_ID} --route-table-id ${FW_PUBLIC_RT_ID} > /dev/null
echo "SUCCESS: IGW e NAT Gateway configurados."

# --- 3. Criar e Configurar o Network Firewall ---
echo "INFO: Criando Network Firewall e política..."
# Criar grupo de regras stateful (Domain Filtering)
STATEFUL_RULE_GROUP_ARN=$(aws network-firewall create-rule-group \
  --rule-group-name Domain-Filtering-Rules \
  --type STATEFUL \
  --capacity 100 \
  --rule-group '{"RulesSource":{"RulesSourceList":{"Targets":["www.amazon.com"],"TargetTypes":["TLS_SNI"],"GeneratedRulesType":"ALLOWLIST"}},"StatefulRuleOptions":{"RuleOrder":"STRICT_ORDER"}}' \
  --query 'RuleGroupResponse.RuleGroupArn' \
  --output text)
echo "Stateful Rule Group criado: ${STATEFUL_RULE_GROUP_ARN}"

# Criar política de firewall
FIREWALL_POLICY_ARN=$(aws network-firewall create-firewall-policy \
  --firewall-policy-name Lab-Firewall-Policy \
  --firewall-policy '{"StatelessDefaultActions":["aws:forward_to_sfn"],"StatelessFragmentDefaultActions":["aws:forward_to_sfn"],"StatefulRuleGroupReferences":[{"ResourceArn":"'${STATEFUL_RULE_GROUP_ARN}'"}],"StatefulDefaultActions":["DROP"]}' \
  --query 'FirewallPolicyResponse.FirewallPolicyArn' \
  --output text)
echo "Firewall Policy criada: ${FIREWALL_POLICY_ARN}"

# Criar o Firewall
FIREWALL_ARN=$(aws network-firewall create-firewall \
  --firewall-name Lab-Firewall \
  --vpc-id ${FW_VPC_ID} \
  --subnet-mappings SubnetId=${FIREWALL_SUBNET_ID} \
  --firewall-policy-arn ${FIREWALL_POLICY_ARN} \
  --query 'Firewall.FirewallArn' \
  --output text)

echo "Network Firewall criado: ${FIREWALL_ARN}. Aguardando ficar disponível..."
aws network-firewall wait firewall-available --firewall-arn ${FIREWALL_ARN}

FIREWALL_ENDPOINT_ID=$(aws network-firewall describe-firewall \
  --firewall-arn ${FIREWALL_ARN} \
  --query 'FirewallStatus.SyncStates.${AVAILABILITY_ZONE}.Attachment.EndpointId' \
  --output text)
echo "Firewall Endpoint ID: ${FIREWALL_ENDPOINT_ID}"

# --- 4. Configurar o Roteamento para Forçar a Inspeção ---
echo "INFO: Configurando roteamento para forçar inspeção pelo Network Firewall..."

# Tabela de Rotas da Subnet-App (todo o tráfego para o Firewall Endpoint)
APP_RT_ID=$(aws ec2 create-route-table \
  --vpc-id ${FW_VPC_ID} \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${FW_VPC_NAME}-App-RT}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
aws ec2 create-route --route-table-id ${APP_RT_ID} --destination-cidr-block 0.0.0.0/0 --vpc-endpoint-id ${FIREWALL_ENDPOINT_ID} > /dev/null
aws ec2 associate-route-table --subnet-id ${APP_SUBNET_ID} --route-table-id ${APP_RT_ID} > /dev/null
echo "Rotas para App-Subnet configuradas."

# Tabela de Rotas do Firewall (tráfego do Firewall para o NAT GW)
FIREWALL_RT_ID=$(aws ec2 create-route-table \
  --vpc-id ${FW_VPC_ID} \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${FW_VPC_NAME}-Firewall-RT}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)
aws ec2 create-route --route-table-id ${FIREWALL_RT_ID} --destination-cidr-block 0.0.0.0/0 --nat-gateway-id ${FW_NAT_GW_ID} > /dev/null
aws ec2 associate-route-table --subnet-id ${FIREWALL_SUBNET_ID} --route-table-id ${FIREWALL_RT_ID} > /dev/null
echo "Rotas para Firewall-Subnet configuradas."

# Tabela de Rotas do IGW (tráfego de retorno da internet para o Firewall Endpoint)
# Obter a tabela de rotas principal da VPC (onde o IGW está anexado por padrão)
MAIN_RT_ID=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=${FW_VPC_ID} Name=association.main,Values=true --query 'RouteTables[0].RouteTableId' --output text)
aws ec2 create-route --route-table-id ${MAIN_RT_ID} --destination-cidr-block ${FW_VPC_CIDR} --vpc-endpoint-id ${FIREWALL_ENDPOINT_ID} > /dev/null
echo "Rotas para IGW (retorno) configuradas."

# --- 5. Lançar a Instância e Testar ---
echo "INFO: Lançando instância de teste na App-Subnet..."
APP_INSTANCE_SG_ID=$(aws ec2 create-security-group \
  --group-name App-Instance-SG \
  --description "SG for App Instance" \
  --vpc-id ${FW_VPC_ID} \
  --query 'GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id ${APP_INSTANCE_SG_ID} \
  --protocol tcp \
  --port 22 \
  --cidr ${MY_LOCAL_IP}

APP_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --count 1 \
  --instance-type t2.micro \
  --key-name ${KEY_PAIR_NAME} \
  --subnet-id ${APP_SUBNET_ID} \
  --security-group-ids ${APP_INSTANCE_SG_ID} \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=App-Test-Instance}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "SUCCESS: Instância de teste lançada: ${APP_INSTANCE_ID}. Aguardando..."
aws ec2 wait instance-running --instance-ids ${APP_INSTANCE_ID}
APP_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids ${APP_INSTANCE_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Instância de teste IP Público: ${APP_INSTANCE_PUBLIC_IP}"

echo "-------------------------------------"
echo "Configuração do Network Firewall concluída!"
echo "Firewall ARN: ${FIREWALL_ARN}"
echo "Instância de Teste IP Público: ${APP_INSTANCE_PUBLIC_IP}"
echo "-------------------------------------"

echo "
--- Próximos Passos (Validação) ---"
echo "1. Faça SSH para a instância App-Test-Instance (${APP_INSTANCE_PUBLIC_IP})."
echo "2. Dentro da instância, execute:"
echo "   curl -I https://www.amazon.com  (Deve funcionar)"
echo "   curl -I https://www.google.com   (Deve falhar com timeout)"

# --- Comandos de Limpeza ---

# Para terminar a instância de teste
# aws ec2 terminate-instances --instance-ids ${APP_INSTANCE_ID}
# aws ec2 wait instance-terminated --instance-ids ${APP_INSTANCE_ID}

# Para deletar o Security Group da instância de teste
# aws ec2 delete-security-group --group-id ${APP_INSTANCE_SG_ID}

# Para deletar as rotas criadas
# aws ec2 delete-route --route-table-id ${APP_RT_ID} --destination-cidr-block 0.0.0.0/0
# aws ec2 delete-route --route-table-id ${FIREWALL_RT_ID} --destination-cidr-block 0.0.0.0/0
# aws ec2 delete-route --route-table-id ${MAIN_RT_ID} --destination-cidr-block ${FW_VPC_CIDR}

# Para deletar as tabelas de rotas customizadas
# aws ec2 delete-route-table --route-table-id ${APP_RT_ID}
# aws ec2 delete-route-table --route-table-id ${FIREWALL_RT_ID}

# Para deletar o Network Firewall
# aws network-firewall delete-firewall --firewall-arn ${FIREWALL_ARN}
# aws network-firewall wait firewall-deleted --firewall-arn ${FIREWALL_ARN}

# Para deletar a Firewall Policy
# aws network-firewall delete-firewall-policy --firewall-policy-arn ${FIREWALL_POLICY_ARN}

# Para deletar o Rule Group
# aws network-firewall delete-rule-group --rule-group-arn ${STATEFUL_RULE_GROUP_ARN}

# Para deletar o NAT Gateway
# aws ec2 delete-nat-gateway --nat-gateway-id ${FW_NAT_GW_ID}
# aws ec2 release-address --allocation-id ${FW_NAT_EIP_ALLOC_ID}

# Para desanexar e deletar o Internet Gateway
# aws ec2 detach-internet-gateway --internet-gateway-id ${FW_IGW_ID} --vpc-id ${FW_VPC_ID}
# aws ec2 delete-internet-gateway --internet-gateway-id ${FW_IGW_ID}

# Para deletar as sub-redes
# aws ec2 delete-subnet --subnet-id ${APP_SUBNET_ID}
# aws ec2 delete-subnet --subnet-id ${FIREWALL_SUBNET_ID}
# aws ec2 delete-subnet --subnet-id ${PUBLIC_SUBNET_ID}

# Para deletar a VPC
# aws ec2 delete-vpc --vpc-id ${FW_VPC_ID}