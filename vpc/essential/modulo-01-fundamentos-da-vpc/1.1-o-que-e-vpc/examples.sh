#!/bin/bash

# Criar uma VPC com um bloco CIDR
aws ec2 create-vpc --cidr-block 10.0.0.0/16
