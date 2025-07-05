#!/bin/bash

# Criar um Transit Gateway
aws ec2 create-transit-gateway --description "My Transit Gateway"

# Anexar uma VPC a um Transit Gateway
aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id tgw-0abcdef1234567890 --vpc-id vpc-0abcdef1234567890 --subnet-ids subnet-0abcdef1234567890
