#!/bin/bash

# Criar uma ACL de rede
aws ec2 create-network-acl --vpc-id vpc-0abcdef1234567890

# Criar uma entrada de ACL de rede
aws ec2 create-network-acl-entry --network-acl-id acl-0abcdef1234567890 --ingress --rule-number 100 --protocol tcp --port-range From=80,To=80 --cidr-block 0.0.0.0/0 --rule-action allow
