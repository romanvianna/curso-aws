#!/bin/bash

# Listar IDs de instâncias em uma VPC específica
aws ec2 describe-instances --filters "Name=vpc-id,Values=vpc-0abcdef1234567890" --query "Reservations[*].Instances[*].InstanceId" --output text

# Parar todas as instâncias em uma VPC específica
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=vpc-0abcdef1234567890" --query "Reservations[*].Instances[*].InstanceId" --output text)
if [ -n "$INSTANCE_IDS" ]; then
  aws ec2 stop-instances --instance-ids $INSTANCE_IDS
else
  echo "Nenhuma instância encontrada na VPC especificada."
fi
