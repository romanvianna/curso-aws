#!/bin/bash

# Criar um Customer Gateway
aws ec2 create-customer-gateway --type ipsec.1 --public-ip 203.0.113.12 --bgp-asn 65000

# Criar um Virtual Private Gateway
aws ec2 create-vpn-gateway --type ipsec.1

# Anexar o Virtual Private Gateway à VPC
aws ec2 attach-vpn-gateway --vpn-gateway-id vgw-0abcdef1234567890 --vpc-id vpc-0abcdef1234567890

# Criar uma conexão VPN
aws ec2 create-vpn-connection --type ipsec.1 --customer-gateway-id cgw-0abcdef1234567890 --vpn-gateway-id vgw-0abcdef1234567890
