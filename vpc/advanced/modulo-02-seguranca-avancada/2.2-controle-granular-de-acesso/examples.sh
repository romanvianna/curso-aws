#!/bin/bash

# Criar uma política IAM para acesso granular à VPC
aws iam create-policy --policy-name MyVPCAdminAccess --policy-document file://vpc-admin-policy.json

# Anexar a política a um grupo de usuários
aws iam attach-group-policy --group-name VPCAdmins --policy-arn arn:aws:iam::123456789012:policy/MyVPCAdminAccess
