#!/bin/bash

# --- Exemplo de provisionamento via AWS CLI ---

# Cenário: Configurar um Application Load Balancer (ALB) para usar HTTPS
# com um certificado do AWS Certificate Manager (ACM) e redirecionar HTTP para HTTPS.

# Pré-requisitos:
# 1. Um ALB existente (substitua <ALB_ARN>).
# 2. Um Target Group existente (substitua <TARGET_GROUP_ARN>).
# 3. Um certificado SSL/TLS emitido e validado no AWS Certificate Manager (ACM).
#    (A emissão de certificado via CLI é complexa e geralmente feita via console ou SDKs).
#    Substitua <ACM_CERTIFICATE_ARN> pelo ARN do seu certificado.
# 4. O Security Group do ALB deve permitir tráfego na porta 443.

# Variáveis de exemplo (substitua pelos seus ARNs reais)
# ALB_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-application-lb/abcdef1234567890"
# TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/my-web-app-tg/abcdef1234567890"
# ACM_CERTIFICATE_ARN="arn:aws:acm:us-east-1:123456789012:certificate/abcdefg-1234-5678-9012-abcdefghijkl"

echo "--- Adicionando Listener HTTPS ao ALB ---"

# Cria um listener HTTPS na porta 443 que encaminha para o Target Group
aws elbv2 create-listener \
  --load-balancer-arn ${ALB_ARN} \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=${ACM_CERTIFICATE_ARN} \
  --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}

echo "Listener HTTPS criado para o ALB."

echo "--- Configurando Redirecionamento HTTP para HTTPS ---"

# Obtém o ARN do listener HTTP existente (porta 80)
HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn ${ALB_ARN} \
  --query 'Listeners[?Port==`80`].ListenerArn' \
  --output text)

if [ -z "$HTTP_LISTENER_ARN" ]; then
  echo "Nenhum listener HTTP na porta 80 encontrado. Criando um..."
  # Se não houver listener HTTP, cria um que já redireciona
  aws elbv2 create-listener \
    --load-balancer-arn ${ALB_ARN} \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=redirect,RedirectConfig={\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}
else
  echo "Modificando listener HTTP existente para redirecionar para HTTPS."
  # Modifica o listener HTTP existente para redirecionar para HTTPS
  aws elbv2 modify-listener \
    --listener-arn ${HTTP_LISTENER_ARN} \
    --default-actions Type=redirect,RedirectConfig={\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}
fi

echo "Redirecionamento HTTP para HTTPS configurado."

echo "\n--- Próximos Passos ---"
echo "1. Certifique-se de que o Security Group do seu ALB permite tráfego na porta 443."
echo "2. Crie um registro DNS (CNAME ou A Alias) que aponte seu domínio (ex: app.seusite.com) para o DNS Name do seu ALB."
echo "3. Teste acessando http://seu-dominio.com e https://seu-dominio.com no navegador."

# --- Comandos de Limpeza ---

# Para deletar o listener HTTPS
# aws elbv2 delete-listener --listener-arn <HTTPS_LISTENER_ARN>

# Para reverter o listener HTTP (se você o modificou)
# aws elbv2 modify-listener --listener-arn <HTTP_LISTENER_ARN> --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}