# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um tópico SNS para notificações e um alarme CloudWatch
# para monitorar a saúde de um Application Load Balancer (ALB).

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Um ALB existente (referenciado como 'aws_lb.lab_alb').
# - Um Target Group existente (referenciado como 'aws_lb_target_group.lab_app_tg').

# Variável para o e-mail de notificação
variable "notification_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}

# 1. Criação do Tópico SNS para Notificações
# Este tópico será usado para enviar alertas quando o alarme for disparado.
resource "aws_sns_topic" "critical_app_alarms_topic" {
  name = "Critical-App-Alarms"

  tags = {
    Name = "CriticalAppAlarmsTopic"
  }
}

# 2. Assinatura do E-mail ao Tópico SNS
# O e-mail fornecido na variável 'notification_email' será inscrito no tópico SNS.
# Uma confirmação será enviada para este e-mail.
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.critical_app_alarms_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# 3. Criação do Alarme CloudWatch para ALB UnHealthyHostCount
# Este alarme monitora a métrica de hosts não saudáveis do ALB e dispara
# se o número de hosts não saudáveis for maior que zero.
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts_critical_alarm" {
  alarm_name          = "ALB_Unhealthy_Hosts_CRITICAL"
  alarm_description   = "Alarme para hosts não saudáveis no Application Load Balancer"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60 # Avalia a cada 60 segundos
  statistic           = "Maximum"
  threshold           = 0 # Dispara se o número de hosts não saudáveis for maior que 0
  datapoints_to_alarm = 1 # Dispara no primeiro ponto de dados que viola o limite

  # Dimensões para identificar o ALB e o Target Group específicos
  dimensions = {
    LoadBalancer = aws_lb.lab_alb.arn # ARN do seu ALB
    TargetGroup  = aws_lb_target_group.lab_app_tg.arn # ARN do seu Target Group
  }

  # Ação a ser tomada quando o alarme estiver no estado ALARM
  alarm_actions = [aws_sns_topic.critical_app_alarms_topic.arn]

  # Ação a ser tomada quando o alarme estiver no estado OK
  ok_actions = [aws_sns_topic.critical_app_alarms_topic.arn]

  # Trata dados ausentes como 'notBreaching' para evitar alarmes falsos
  treat_missing_data = "notBreaching"

  tags = {
    Name = "ALBUnhealthyHostsCriticalAlarm"
  }
}

# Saídas (Outputs) para facilitar a referência e verificação
output "sns_topic_arn" {
  description = "The ARN of the SNS topic for critical alarms"
  value       = aws_sns_topic.critical_app_alarms_topic.arn
}

output "cloudwatch_alarm_arn" {
  description = "The ARN of the CloudWatch alarm for ALB unhealthy hosts"
  value       = aws_cloudwatch_metric_alarm.alb_unhealthy_hosts_critical_alarm.arn
}