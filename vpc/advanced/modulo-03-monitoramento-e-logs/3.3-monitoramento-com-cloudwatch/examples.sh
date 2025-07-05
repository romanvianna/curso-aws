#!/bin/bash

# Listar métricas do CloudWatch para VPC
aws cloudwatch list-metrics --namespace AWS/EC2 --metric-name NetworkIn --dimensions Name=VPC,Value=vpc-0abcdef1234567890

# Criar um alarme do CloudWatch
aws cloudwatch put-metric-alarm --alarm-name "HighNetworkIn" --metric-name NetworkIn --namespace AWS/EC2 --statistic Sum --period 300 --threshold 1000000000 --comparison-operator GreaterThanThreshold --dimensions Name=VPC,Value=vpc-0abcdef1234567890 --evaluation-periods 2 --alarm-actions arn:aws:sns:us-east-1:123456789012:MyTopic
