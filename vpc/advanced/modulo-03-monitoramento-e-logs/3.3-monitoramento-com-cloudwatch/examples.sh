#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Criar um tópico SNS para notificações e um alarme CloudWatch
# para monitorar a saúde de um Application Load Balancer (ALB).

# Pré-requisitos:
# 1. Um ALB existente e um Target Group associado (substitua <ALB_ARN> e <TARGET_GROUP_ARN>).
# 2. Um endereço de e-mail para receber as notificações.

# Variáveis de exemplo (substitua pelos seus ARNs/Nomes reais)
# ALB_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-application-lb/abcdef1234567890"
# TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/my-web-app-tg/abcdef1234567890"
# YOUR_EMAIL="seu.email@example.com"

echo "--- Criando Tópico SNS para Notificações ---"

SNS_TOPIC_ARN=$(aws sns create-topic \
  --name Critical-App-Alarms \
  --query 'TopicArn' \
  --output text)

echo "Tópico SNS criado: $SNS_TOPIC_ARN"

# Assinar o e-mail ao tópico SNS
aws sns subscribe \
  --topic-arn ${SNS_TOPIC_ARN} \
  --protocol email \
  --notification-endpoint ${YOUR_EMAIL}

echo "Assinatura de e-mail para ${YOUR_EMAIL} adicionada. Por favor, confirme a inscrição no seu e-mail."

echo "--- Criando Alarme CloudWatch para ALB UnHealthyHostCount ---"

# Obtém o nome do Target Group a partir do ARN
TARGET_GROUP_NAME=$(echo ${TARGET_GROUP_ARN} | awk -F'/' '{print $2}')

aws cloudwatch put-metric-alarm \
  --alarm-name ALB_Unhealthy_Hosts_CRITICAL \
  --alarm-description "Alarme para hosts não saudáveis no ALB" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Maximum \
  --period 60 \
  --threshold 0 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=LoadBalancer,Value=$(echo ${ALB_ARN} | awk -F'/' '{print $3}') Name=TargetGroup,Value=${TARGET_GROUP_NAME} \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --treat-missing-data notBreaching \
  --alarm-actions ${SNS_TOPIC_ARN}

echo "Alarme CloudWatch 'ALB_Unhealthy_Hosts_CRITICAL' criado."

echo "\n--- Próximos Passos ---"
echo "1. Confirme a inscrição do seu e-mail no tópico SNS."
echo "2. Para testar o alarme, pare uma instância EC2 que esteja no Target Group do seu ALB."
echo "3. Verifique seu e-mail para a notificação do alarme."

# --- Comandos de Limpeza ---

# Para deletar o alarme
# aws cloudwatch delete-alarms --alarm-names ALB_Unhealthy_Hosts_CRITICAL

# Para cancelar a assinatura do tópico SNS
# aws sns unsubscribe --subscription-arn <SUBSCRIPTION_ARN> # Obtenha o ARN da assinatura com aws sns list-subscriptions

# Para deletar o tópico SNS
# aws sns delete-topic --topic-arn ${SNS_TOPIC_ARN}