# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação e configuração de uma Network ACL (NACL)
# customizada, incluindo regras de ALLOW e DENY, e sua associação a uma sub-rede.
# O objetivo é solidificar o entendimento das NACLs como firewalls stateless em nível de sub-rede.

# Pré-requisitos (assumidos como já existentes ou criados em outros módulos):
# - Uma VPC existente (referenciada como 'aws_vpc.custom_vpc').
# - Uma sub-rede pública existente (referenciada como 'aws_subnet.public_subnet').

# Variáveis para configuração da NACL
variable "vpc_id" {
  description = "The ID of the VPC where the NACL will be created."
  type        = string
}

variable "public_subnet_id" {
  description = "The ID of the public subnet to associate the NACL with."
  type        = string
}

variable "my_local_ip" {
  description = "Your local public IP address for SSH access (e.g., 203.0.113.10/32)"
  type        = string
}

variable "malicious_ip" {
  description = "A fictitious malicious IP address to block (e.g., 203.0.113.5/32)"
  type        = string
  default     = "203.0.113.5/32"
}

# 1. Criação da Network ACL customizada
# Por padrão, uma NACL customizada nega todo o tráfego até que regras de ALLOW sejam adicionadas.
resource "aws_network_acl" "lab_public_nacl" {
  vpc_id = var.vpc_id

  tags = {
    Name = "Lab-Public-NACL"
  }
}

# 2. Regras de Entrada (Inbound) para a NACL
# As regras são processadas em ordem numérica (menor para maior).
# A primeira regra que corresponde ao tráfego é aplicada.

# Regra 90: DENY para IP malicioso (prioridade alta para bloquear antes de outras regras)
resource "aws_network_acl_rule" "deny_malicious_ip_inbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 90
  protocol       = "-1" # All protocols
  rule_action    = "deny"
  cidr_block     = var.malicious_ip
  egress         = false # Inbound rule
  
  depends_on = [aws_network_acl.lab_public_nacl] # Garante que a NACL exista antes de adicionar regras
}

# Regra 100: ALLOW HTTP (80) de qualquer lugar
resource "aws_network_acl_rule" "allow_http_inbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = false
}

# Regra 110: ALLOW HTTPS (443) de qualquer lugar
resource "aws_network_acl_rule" "allow_https_inbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
  egress         = false
}

# Regra 120: ALLOW SSH (22) do seu IP local
resource "aws_network_acl_rule" "allow_ssh_inbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.my_local_ip
  from_port      = 22
  to_port        = 22
  egress         = false
}

# Regra 130: ALLOW portas efêmeras (1024-65535) para tráfego de resposta de saída
# Necessário para NACLs stateless para que as respostas de conexões iniciadas de dentro da VPC possam sair.
resource "aws_network_acl_rule" "allow_ephemeral_outbound_response_inbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 130
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
  egress         = false
}

# 3. Regras de Saída (Outbound) para a NACL

# Regra 100: ALLOW HTTP (80) para qualquer lugar
resource "aws_network_acl_rule" "allow_http_outbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = true # Outbound rule
}

# Regra 110: ALLOW HTTPS (443) para qualquer lugar
resource "aws_network_acl_rule" "allow_https_outbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
  egress         = true
}

# Regra 120: ALLOW SSH (22) para o seu IP local (para respostas SSH)
resource "aws_network_acl_rule" "allow_ssh_outbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.my_local_ip
  from_port      = 22
  to_port        = 22
  egress         = true
}

# Regra 130: ALLOW portas efêmeras (1024-65535) para tráfego de resposta de entrada
# Necessário para NACLs stateless para que as respostas de conexões iniciadas de fora da VPC possam entrar.
resource "aws_network_acl_rule" "allow_ephemeral_inbound_response_outbound" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  rule_number    = 130
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
  egress         = true
}

# 4. Associação da NACL à Sub-rede Pública
resource "aws_network_acl_association" "lab_public_subnet_nacl_association" {
  network_acl_id = aws_network_acl.lab_public_nacl.id
  subnet_id      = var.public_subnet_id
}

# Saídas (Outputs) para facilitar a verificação
output "lab_public_nacl_id" {
  description = "The ID of the created Lab Public Network ACL"
  value       = aws_network_acl.lab_public_nacl.id
}