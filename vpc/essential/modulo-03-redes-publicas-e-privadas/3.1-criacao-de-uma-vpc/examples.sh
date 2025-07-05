#!/bin/bash

# Criar uma VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=MyCustomVPC}]'

# Criar uma sub-rede pública
aws ec2 create-subnet --vpc-id vpc-0abcdef1234567890 --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=MyPublicSubnet}]'

# Criar uma sub-rede privada
aws ec2 create-subnet --vpc-id vpc-0abcdef1234567890 --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=MyPrivateSubnet}]'
