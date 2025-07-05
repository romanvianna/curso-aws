#!/bin/bash

# Criar uma solicitação de peering de VPC
aws ec2 create-vpc-peering-connection --vpc-id vpc-0abcdef1234567890 --peer-vpc-id vpc-0abcdef1234567891 --peer-region us-east-1

# Aceitar uma solicitação de peering de VPC
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id pcx-0abcdef1234567890

# Adicionar rotas para o peering de VPC
aws ec2 create-route --route-table-id rtb-0abcdef1234567890 --destination-cidr-block 10.1.0.0/16 --vpc-peering-connection-id pcx-0abcdef1234567890
