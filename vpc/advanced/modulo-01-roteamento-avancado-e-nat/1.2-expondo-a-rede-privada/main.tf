# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação de um Application Load Balancer (ALB)
# para expor uma aplicação web em sub-redes privadas de forma segura e escalável.

# Pré-requisitos:
# - Uma VPC existente (referenciada aqui como 'aws_vpc.custom_vpc').
# - Sub-redes públicas existentes em pelo menos duas AZs (referenciadas como 'aws_subnet.public_subnet_az1' e 'aws_subnet.public_subnet_az2').
# - Sub-redes privadas existentes em pelo menos duas AZs (referenciadas como 'aws_subnet.private_subnet_az1' e 'aws_subnet.private_subnet_az2').
# - Instâncias EC2 em sub-redes privadas que servirão como alvos do ALB.

# Exemplo de como você poderia definir a VPC e as sub-redes em um arquivo separado
# ou em um módulo, se não estiverem já definidas.
# resource "aws_vpc" "custom_vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = { Name = "LabVPC" }
# }

# resource "aws_subnet" "public_subnet_az1" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.1.0/24"
#   availability_zone = "us-east-1a"
#   map_public_ip_on_launch = true
#   tags = { Name = "LabPublicSubnetAZ1" }
# }

# resource "aws_subnet" "public_subnet_az2" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.2.0/24"
#   availability_zone = "us-east-1b"
#   map_public_ip_on_launch = true
#   tags = { Name = "LabPublicSubnetAZ2" }
# }

# resource "aws_subnet" "private_subnet_az1" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.3.0/24"
#   availability_zone = "us-east-1a"
#   tags = { Name = "LabPrivateSubnetAZ1" }
# }

# resource "aws_subnet" "private_subnet_az2" {
#   vpc_id            = aws_vpc.custom_vpc.id
#   cidr_block        = "10.0.4.0/24"
#   availability_zone = "us-east-1b"
#   tags = { Name = "LabPrivateSubnetAZ2" }
# }

# resource "aws_security_group" "app_sg" {
#   name        = "LabAppSecurityGroup"
#   description = "Allow HTTP from ALB"
#   vpc_id      = aws_vpc.custom_vpc.id
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     security_groups = [aws_security_group.alb_sg.id] # Permite tráfego apenas do SG do ALB
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = { Name = "LabAppSecurityGroup" }
# }

# resource "aws_instance" "app_server_a" {
#   ami           = "ami-0abcdef1234567890" # Substitua por uma AMI Linux válida
#   instance_type = "t2.micro"
#   subnet_id     = aws_subnet.private_subnet_az1.id
#   security_groups = [aws_security_group.app_sg.id]
#   user_data = <<-EOF
#               #!/bin/bash
#               yum update -y
#               yum install -y httpd
#               systemctl start httpd
#               systemctl enable httpd
#               INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
#               echo "<h1>Request handled by AppServer: $INSTANCE_ID</h1>" > /var/www/html/index.html
#               EOF
#   tags = { Name = "AppServer-A" }
# }

# resource "aws_instance" "app_server_b" {
#   ami           = "ami-0abcdef1234567890" # Substitua por uma AMI Linux válida
#   instance_type = "t2.micro"
#   subnet_id     = aws_subnet.private_subnet_az2.id
#   security_groups = [aws_security_group.app_sg.id]
#   user_data = <<-EOF
#               #!/bin/bash
#               yum update -y
#               yum install -y httpd
#               systemctl start httpd
#               systemctl enable httpd
#               INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
#               echo "<h1>Request handled by AppServer: $INSTANCE_ID</h1>" > /var/www/html/index.html
#               EOF
#   tags = { Name = "AppServer-B" }
# }

# 1. Security Group para o ALB
# Permite tráfego HTTP e HTTPS de qualquer lugar da internet.
resource "aws_security_group" "alb_sg" {
  name        = "LabALBSecurityGroup"
  description = "Allow HTTP and HTTPS traffic to ALB"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "LabALBSecurityGroup" }
}

# 2. Target Group para as instâncias de aplicação
# Define como o ALB encaminhará o tráfego para as instâncias.
resource "aws_lb_target_group" "lab_app_tg" {
  name     = "LabAppTargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.custom_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "LabAppTargetGroup" }
}

# 3. Anexa as instâncias ao Target Group
resource "aws_lb_target_group_attachment" "app_server_a_attachment" {
  target_group_arn = aws_lb_target_group.lab_app_tg.arn
  target_id        = aws_instance.app_server_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app_server_b_attachment" {
  target_group_arn = aws_lb_target_group.lab_app_tg.arn
  target_id        = aws_instance.app_server_b.id
  port             = 80
}

# 4. Cria o Application Load Balancer (ALB)
# O ALB é internet-facing e distribuído entre as sub-redes públicas.
resource "aws_lb" "lab_alb" {
  name               = "lab-application-lb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]

  enable_deletion_protection = false # Defina como true em produção

  tags = { Name = "LabApplicationLoadBalancer" }
}

# 5. Listener HTTP para o ALB
# Encaminha o tráfego da porta 80 para o Target Group.
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.lab_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lab_app_tg.arn
  }
}

# Saídas (Outputs) para facilitar a referência em outros módulos ou para verificação
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.lab_alb.dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.lab_alb.arn
}