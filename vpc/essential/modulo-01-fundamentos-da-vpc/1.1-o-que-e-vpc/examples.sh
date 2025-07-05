#!/bin/bash

# --- Exemplo de comandos AWS CLI para explorar componentes da VPC ---

# Cenário: Após a teoria sobre o que é uma VPC e seus componentes,
# este script demonstra como usar a AWS CLI para listar e descrever
# esses componentes na sua conta AWS.

echo "--- 1. Descrevendo suas VPCs ---"
# Lista todas as VPCs na sua conta e região atual.
# Inclui informações como VPC ID, CIDR block e tags.
aws ec2 describe-vpcs \
  --query "Vpcs[*].{ID:VpcId,CIDR:CidrBlock,IsDefault:IsDefault,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 2. Descrevendo suas Sub-redes ---"
# Lista todas as sub-redes, mostrando a qual VPC pertencem, seus CIDRs,
# Zona de Disponibilidade e se auto-atribuem IPs públicos.
aws ec2 describe-subnets \
  --query "Subnets[*].{ID:SubnetId,VPC_ID:VpcId,CIDR:CidrBlock,AZ:AvailabilityZone,AutoPublicIp:MapPublicIpOnLaunch,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 3. Descrevendo seus Internet Gateways ---"
# Lista todos os Internet Gateways e as VPCs às quais estão anexados.
aws ec2 describe-internet-gateways \
  --query "InternetGateways[*].{ID:InternetGatewayId,AttachedVPC:Attachments[0].VpcId,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 4. Descrevendo suas Tabelas de Rotas ---"
# Lista as tabelas de rotas, suas VPCs associadas e se são a tabela principal.
aws ec2 describe-route-tables \
  --query "RouteTables[*].{ID:RouteTableId,VPC_ID:VpcId,IsMain:Associations[?Main==`true`].Main | [0],Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 5. Descrevendo suas Network ACLs ---"
# Lista as Network ACLs e suas VPCs associadas.
aws ec2 describe-network-acls \
  --query "NetworkAcls[*].{ID:NetworkAclId,VPC_ID:VpcId,IsDefault:IsDefault,Name:Tags[?Key==`Name`].Value | [0]}" \
  --output table

echo "\n--- 6. Descrevendo seus Security Groups ---"
# Lista os Security Groups, suas VPCs associadas e descrições.
aws ec2 describe-security-groups \
  --query "SecurityGroups[*].{ID:GroupId,Name:GroupName,VPC_ID:VpcId,Description:Description}" \
  --output table

echo "\nExploração dos componentes da VPC concluída. Use os IDs para descrever recursos específicos em mais detalhes."