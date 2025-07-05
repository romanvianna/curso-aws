#!/bin/bash

# Iniciar uma instância em uma sub-rede pública
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --count 1 --instance-type t2.micro --subnet-id subnet-0abcdef1234567890 --associate-public-ip-address

# Iniciar uma instância em uma sub-rede privada
aws ec2 run-instances --image-id ami-0c55b159cbfafe1f0 --count 1 --instance-type t2.micro --subnet-id subnet-0abcdef1234567891
