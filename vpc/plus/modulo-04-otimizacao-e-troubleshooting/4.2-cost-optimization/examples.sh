#!/bin/bash

# Descrever instâncias reservadas
aws ec2 describe-reserved-instances

# Descrever instâncias spot
aws ec2 describe-spot-instance-requests

# Obter o custo e uso com o AWS Cost Explorer
# aws ce get-cost-and-usage --time-period Start=2023-01-01,End=2023-01-31 --granularity MONTHLY --metrics BlendedCost
