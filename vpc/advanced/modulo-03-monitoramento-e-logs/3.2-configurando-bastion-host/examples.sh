#!/bin/bash

# Iniciar uma instância EC2 para ser o bastion host
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --count 1 --instance-type t2.micro --subnet-id subnet-0abcdef1234567890 --security-group-ids sg-0abcdef1234567890 --associate-public-ip-address --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=BastionHost}]'
