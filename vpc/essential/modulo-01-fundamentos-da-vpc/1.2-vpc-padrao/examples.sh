#!/bin/bash

# Descrever a VPC padrão
aws ec2 describe-vpcs --filters Name=isDefault,Values=true
