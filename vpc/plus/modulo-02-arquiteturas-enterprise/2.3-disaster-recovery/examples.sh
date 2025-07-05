#!/bin/bash

# Exemplo de replicação de AMI para outra região para DR
aws ec2 copy-image --source-image-id ami-0abcdef1234567890 --source-region us-east-1 --name "MyDRImage" --destination-region us-west-2

# Exemplo de criação de um plano de backup com AWS Backup
# aws backup create-backup-plan --backup-plan file://backup-plan.json
