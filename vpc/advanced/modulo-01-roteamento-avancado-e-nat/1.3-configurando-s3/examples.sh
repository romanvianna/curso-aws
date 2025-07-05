#!/bin/bash

# Criar um bucket S3
aws s3 mb s3://my-unique-vpc-bucket-12345

# Fazer upload de um arquivo para um bucket S3
aws s3 cp my-file.txt s3://my-unique-vpc-bucket-12345/my-file.txt
