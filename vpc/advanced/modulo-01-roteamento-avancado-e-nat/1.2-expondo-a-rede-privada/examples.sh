#!/bin/bash

# Criar um Application Load Balancer (ALB)
aws elbv2 create-load-balancer --name my-alb --subnets subnet-0abcdef1234567890 subnet-0abcdef1234567891 --security-groups sg-0abcdef1234567890

# Criar um grupo de destino
aws elbv2 create-target-group --name my-targets --protocol HTTP --port 80 --vpc-id vpc-0abcdef1234567890

# Registrar instâncias no grupo de destino
aws elbv2 register-targets --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/my-targets/abcdef1234567890 --targets Id=i-0abcdef1234567890
