#!/bin/bash

# Criar um NAT Gateway
aws ec2 create-nat-gateway --subnet-id subnet-0abcdef1234567890 --allocation-id eipalloc-0abcdef1234567890

# Descrever NAT Gateways
aws ec2 describe-nat-gateways
