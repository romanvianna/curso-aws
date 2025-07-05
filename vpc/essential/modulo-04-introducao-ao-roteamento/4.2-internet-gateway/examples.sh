#!/bin/bash

# Criar um Internet Gateway
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=MyInternetGateway}]'

# Anexar um Internet Gateway a uma VPC
aws ec2 attach-internet-gateway --internet-gateway-id igw-0abcdef1234567890 --vpc-id vpc-0abcdef1234567890
