# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a configuração de um Application Load Balancer (ALB)
# para usar HTTPS com um certificado do AWS Certificate Manager (ACM) e
# redirecionar todo o tráfego HTTP para HTTPS.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Um ALB existente (referenciado como 'aws_lb.lab_alb').
# - Um Target Group existente (referenciado como 'aws_lb_target_group.lab_app_tg').
# - Um Security Group para o ALB que permita tráfego nas portas 80 e 443.
# - Um domínio registrado e configurado para validação do certificado ACM.

# Exemplo de definições de ALB e Target Group (se não existirem):
# resource "aws_lb" "lab_alb" {
#   name               = "lab-application-lb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb_sg.id]
#   subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
#   enable_deletion_protection = false
#   tags = { Name = "LabApplicationLoadBalancer" }
# }

# resource "aws_lb_target_group" "lab_app_tg" {
#   name     = "LabAppTargetGroup"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.custom_vpc.id
#   tags = { Name = "LabAppTargetGroup" }
# }

# Variável para o nome do domínio do certificado
variable "domain_name" {
  description = "The domain name for which the ACM certificate will be issued (e.g., example.com)"
  type        = string
}

# 1. Solicitar um Certificado Público no ACM
# Nota: A validação do certificado (DNS ou Email) precisa ser feita manualmente
# ou via automação externa (ex: Route 53 integration).
resource "aws_acm_certificate" "lab_certificate" {
  domain_name       = var.domain_name
  validation_method = "DNS" # Recomendado para renovação automática

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "LabCertificate" }
}

# Recurso para criar o registro DNS de validação no Route 53 (se o domínio estiver lá)
# resource "aws_route53_record" "lab_certificate_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.lab_certificate.domain_validation_options : dvo.domain_name => dvo
#   }
#   allow_overwrite = true
#   name            = each.value.resource_record_name
#   records         = [each.value.resource_record_value]
#   ttl             = 60
#   type            = each.value.resource_record_type
#   zone_id         = "<YOUR_ROUTE53_HOSTED_ZONE_ID>" # Substitua pelo ID da sua Hosted Zone
# }

# resource "aws_acm_certificate_validation" "lab_certificate_validation" {
#   certificate_arn         = aws_acm_certificate.lab_certificate.arn
#   validation_record_fqdns = [for record in aws_route53_record.lab_certificate_validation : record.fqdn]
# }

# 2. Listener HTTPS para o ALB
# Encaminha o tráfego da porta 443 (HTTPS) para o Target Group.
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.lab_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Política de segurança TLS recomendada
  certificate_arn   = aws_acm_certificate.lab_certificate.arn # Associa o certificado ACM

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lab_app_tg.arn
  }

  tags = { Name = "LabHTTPSListener" }
}

# 3. Listener HTTP para o ALB com Redirecionamento para HTTPS
# Redireciona todo o tráfego da porta 80 (HTTP) para a porta 443 (HTTPS).
resource "aws_lb_listener" "http_listener_redirect" {
  load_balancer_arn = aws_lb.lab_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301" # Redirecionamento permanente
    }
  }

  tags = { Name = "LabHTTPRedirectListener" }
}

# Saídas (Outputs) para facilitar a referência e verificação
output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.lab_certificate.arn
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener"
  value       = aws_lb_listener.https_listener.arn
}