#!/bin/bash

# Criar uma política IAM
aws iam create-policy --policy-name MyVPCReadOnlyAccess --policy-document file://policy.json

# Anexar uma política a um usuário
aws iam attach-user-policy --user-name MyUser --policy-arn arn:aws:iam::123456789012:policy/MyVPCReadOnlyAccess
