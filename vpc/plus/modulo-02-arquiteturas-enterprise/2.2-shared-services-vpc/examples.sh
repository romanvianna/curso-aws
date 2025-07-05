#!/bin/bash

# Exemplo de como configurar uma Shared Services VPC
# Isso geralmente envolve a criação de uma VPC dedicada e o uso de VPC Peering ou Transit Gateway para conectar outras VPCs a ela.

# Criar uma VPC para serviços compartilhados
aws ec2 create-vpc --cidr-block 10.100.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=SharedServicesVPC}]'
