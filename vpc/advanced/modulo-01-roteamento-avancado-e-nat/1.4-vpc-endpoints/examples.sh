#!/bin/bash

# Criar um VPC Endpoint de gateway para S3
aws ec2 create-vpc-endpoint --vpc-id vpc-0abcdef1234567890 --service-name com.amazonaws.us-east-1.s3 --vpc-endpoint-type Gateway --route-table-ids rtb-0abcdef1234567890

# Criar um VPC Endpoint de interface para EC2
aws ec2 create-vpc-endpoint --vpc-id vpc-0abcdef1234567890 --service-name com.amazonaws.us-east-1.ec2 --vpc-endpoint-type Interface --subnet-ids subnet-0abcdef1234567890 --security-group-ids sg-0abcdef1234567890
