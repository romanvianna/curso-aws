#!/bin/bash

# Criar um security group
aws ec2 create-security-group --group-name my-sg --description "My security group"

# Adicionar uma regra de entrada a um security group
aws ec2 authorize-security-group-ingress --group-name my-sg --protocol tcp --port 22 --cidr 0.0.0.0/0
