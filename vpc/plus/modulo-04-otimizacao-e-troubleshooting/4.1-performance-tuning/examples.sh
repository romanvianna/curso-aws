#!/bin/bash

# Descrever métricas de rede de instâncias
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name NetworkIn --dimensions Name=InstanceId,Value=i-0abcdef1234567890 --start-time 2023-01-01T00:00:00Z --end-time 2023-01-01T01:00:00Z --period 300 --statistic Sum

# Modificar o atributo de MTU de uma ENI
# aws ec2 modify-network-interface-attribute --network-interface-id eni-0abcdef1234567890 --no-source-dest-check --mtu 9001
