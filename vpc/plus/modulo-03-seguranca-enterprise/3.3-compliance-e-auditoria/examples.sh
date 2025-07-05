#!/bin/bash

# Habilitar o AWS Config
aws configservice put-configuration-recorder --configuration-recorder name=default,roleARN=arn:aws:iam::123456789012:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig
aws configservice put-delivery-channel --delivery-channel name=default,s3BucketName=my-config-bucket
aws configservice start-configuration-recorder --configuration-recorder-name default

# Descrever regras do AWS Config
aws configservice describe-config-rules
