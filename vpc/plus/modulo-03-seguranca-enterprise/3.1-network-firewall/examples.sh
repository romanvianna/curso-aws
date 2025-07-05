#!/bin/bash

# Criar uma política de firewall de rede
# aws network-firewall create-firewall-policy --firewall-policy-name MyFirewallPolicy --firewall-policy file://firewall-policy.json

# Criar um firewall de rede
# aws network-firewall create-firewall --firewall-name MyFirewall --firewall-policy-arn arn:aws:network-firewall:us-east-1:123456789012:firewall-policy/MyFirewallPolicy --vpc-id vpc-0abcdef1234567890 --subnet-mappings SubnetId=subnet-0abcdef1234567890
