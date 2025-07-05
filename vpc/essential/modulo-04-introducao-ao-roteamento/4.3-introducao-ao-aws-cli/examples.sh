#!/bin/bash

# Listar todas as VPCs
aws ec2 describe-vpcs

# Descrever uma VPC específica
aws ec2 describe-vpcs --vpc-ids vpc-0abcdef1234567890
