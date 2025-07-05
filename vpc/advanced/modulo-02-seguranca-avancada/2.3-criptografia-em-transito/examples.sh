#!/bin/bash

# Criar um certificado SSL/TLS usando AWS Certificate Manager (ACM)
# Nota: A criação de certificados no ACM geralmente é feita via console ou SDKs, não diretamente via CLI para todos os tipos.
# Exemplo de importação de certificado existente:
# aws acm import-certificate --certificate fileb://certificate.pem --private-key fileb://private-key.pem --certificate-chain fileb://certificate-chain.pem

# Associar um certificado a um Load Balancer
# aws elbv2 create-listener --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/abcdef1234567890 --protocol HTTPS --port 443 --certificates CertificateArn=arn:aws:acm:us-east-1:123456789012:certificate/abcdefg-1234-5678-9012-abcdefghijkl --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/my-targets/abcdef1234567890
