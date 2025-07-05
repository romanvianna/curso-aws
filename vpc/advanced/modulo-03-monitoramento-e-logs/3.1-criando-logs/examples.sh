#!/bin/bash

# Criar um Flow Log para uma VPC
aws ec2 create-flow-logs --resource-ids vpc-0abcdef1234567890 --resource-type VPC --traffic-type ALL --log-destination-type s3 --log-destination arn:aws:s3:::my-flow-logs-bucket

# Descrever Flow Logs
aws ec2 describe-flow-logs
