#!/bin/bash

# Exemplo de execução de um pipeline CI/CD com AWS CodePipeline
# aws codepipeline start-pipeline-execution --name MyVpcPipeline

# Exemplo de execução de um script de automação com AWS Systems Manager Run Command
# aws ssm send-command --document-name AWS-RunShellScript --instance-ids i-0abcdef1234567890 --parameters commands=["echo Hello World"]
