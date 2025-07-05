#!/bin/bash

# Descrever tabelas de rotas
aws ec2 describe-route-tables

# Associar uma sub-rede a uma tabela de rotas
aws ec2 associate-route-table --subnet-id subnet-0abcdef1234567890 --route-table-id rtb-0abcdef1234567890
