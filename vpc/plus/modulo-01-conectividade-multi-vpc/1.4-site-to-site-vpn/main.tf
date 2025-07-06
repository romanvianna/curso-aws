# --- Exemplo de provisionamento via Terraform ---

# Este arquivo demonstra a criação dos componentes da AWS para uma conexão
# Site-to-Site VPN. Ele cria um Virtual Private Gateway (VGW), um Customer Gateway (CGW)
# e a conexão VPN. A configuração do lado on-premises é simulada por uma segunda VPC
# e uma instância EC2 que atuaria como o dispositivo VPN on-premises.

# Bloco de configuração do Terraform para especificar o provedor AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use a versão mais recente compatível
    }
  }
}

# Configuração do provedor AWS
provider "aws" {
  region = "us-east-1" # Defina a região da AWS
}

# --- Variáveis de Configuração ---
variable "key_pair_name" {
  description = "The name of the EC2 Key Pair to use for instances"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for EC2 instances (e.g., Amazon Linux 2 AMI)"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Exemplo para us-east-1 Amazon Linux 2
}

variable "my_local_ip" {
  description = "Your local public IP address for SSH access (e.g., 203.0.113.10/32)"
  type        = string
}

# --- VPC A (Nuvem - Produção) ---
resource "aws_vpc" "vpc_cloud" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "VPC-Cloud-VPN"
  }
}

resource "aws_subnet" "subnet_cloud" {
  vpc_id                  = aws_vpc.vpc_cloud.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "VPC-Cloud-Subnet"
  }
}

resource "aws_internet_gateway" "igw_cloud" {
  vpc_id = aws_vpc.vpc_cloud.id

  tags = {
    Name = "VPC-Cloud-IGW"
  }
}

resource "aws_route_table" "rt_cloud" {
  vpc_id = aws_vpc.vpc_cloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_cloud.id
  }

  tags = {
    Name = "VPC-Cloud-RT"
  }
}

resource "aws_route_table_association" "rt_cloud_association" {
  subnet_id      = aws_subnet.subnet_cloud.id
  route_table_id = aws_route_table.rt_cloud.id
}

# Security Group para a instância na VPC Cloud
resource "aws_security_group" "sg_cloud" {
  name        = "VPC-Cloud-SG"
  description = "Allow SSH and ICMP from On-Premises"
  vpc_id      = aws_vpc.vpc_cloud.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16"] # CIDR da VPC On-Premises
  }

  ingress {
    from_port   = -1 # ICMP
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["192.168.0.0/16"] # CIDR da VPC On-Premises
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_local_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instância na VPC Cloud
resource "aws_instance" "cloud_server" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_cloud.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.sg_cloud.id]
  associate_public_ip_address = true

  tags = {
    Name = "Cloud-Server"
  }
}

# --- VPC B (Simula On-Premises - Escritório Remoto) ---
resource "aws_vpc" "vpc_onprem" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "VPC-OnPrem-VPN"
  }
}

resource "aws_subnet" "subnet_onprem" {
  vpc_id                  = aws_vpc.vpc_onprem.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "VPC-OnPrem-Subnet"
  }
}

resource "aws_internet_gateway" "igw_onprem" {
  vpc_id = aws_vpc.vpc_onprem.id

  tags = {
    Name = "VPC-OnPrem-IGW"
  }
}

resource "aws_route_table" "rt_onprem" {
  vpc_id = aws_vpc.vpc_onprem.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_onprem.id
  }

  tags = {
    Name = "VPC-OnPrem-RT"
  }
}

resource "aws_route_table_association" "rt_onprem_association" {
  subnet_id      = aws_subnet.subnet_onprem.id
  route_table_id = aws_route_table.rt_onprem.id
}

# Security Group para a instância On-Prem-Router
resource "aws_security_group" "sg_onprem_router" {
  name        = "VPC-OnPrem-Router-SG"
  description = "Allow VPN traffic and SSH"
  vpc_id      = aws_vpc.vpc_onprem.id

  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow IKE (UDP 500)"
  }

  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow IPsec NAT-T (UDP 4500)"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_local_ip]
    description = "Allow SSH from my local IP"
  }

  ingress {
    from_port   = -1 # ICMP
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_cloud.cidr_block] # Allow Ping from Cloud VPC
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_cloud.cidr_block] # Allow SSH from Cloud VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instância que simula o roteador on-premises
resource "aws_instance" "onprem_router" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_onprem.id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.sg_onprem_router.id]
  associate_public_ip_address = true

  tags = {
    Name = "On-Prem-Router"
  }
}

# --- Componentes da AWS Site-to-Site VPN ---

# 1. Virtual Private Gateway (VGW) - Lado AWS da conexão VPN
resource "aws_vpn_gateway" "lab_vgw" {
  vpc_id = aws_vpc.vpc_cloud.id

  tags = {
    Name = "Lab-VGW-VPN"
  }
}

# 2. Customer Gateway (CGW) - Representa o dispositivo VPN on-premises
resource "aws_customer_gateway" "onprem_cgw" {
  bgp_asn    = "65002" # ASN do seu lado on-premises
  ip_address = aws_instance.onprem_router.public_ip # IP público da instância que simula o roteador on-premises
  type       = "ipsec.1"

  tags = {
    Name = "On-Prem-CGW"
  }
}

# 3. Conexão VPN Site-to-Site
resource "aws_vpn_connection" "aws_to_onprem_vpn" {
  vpn_gateway_id      = aws_vpn_gateway.lab_vgw.id
  customer_gateway_id = aws_customer_gateway.onprem_cgw.id
  type                = "ipsec.1"
  static_routes_only  = false # Habilita BGP para roteamento dinâmico

  tags = {
    Name = "AWS-to-On-Prem-VPN"
  }
}

# 4. Propagação de Rotas na Tabela de Rotas da VPC Cloud
# Permite que a tabela de rotas da VPC Cloud aprenda as rotas da rede on-premises
# anunciadas via BGP pelo VGW.
resource "aws_vpn_connection_route_propagation" "cloud_rt_propagation" {
  vpn_connection_id = aws_vpn_connection.aws_to_onprem_vpn.id
  route_table_id    = aws_route_table.rt_cloud.id
}

# Saídas (Outputs) para facilitar a verificação e configuração do lado on-premises
output "cloud_vpc_id" {
  description = "The ID of the Cloud VPC"
  value       = aws_vpc.vpc_cloud.id
}

output "onprem_vpc_id" {
  description = "The ID of the On-Premises (simulated) VPC"
  value       = aws_vpc.vpc_onprem.id
}

output "vpn_connection_id" {
  description = "The ID of the Site-to-Site VPN Connection"
  value       = aws_vpn_connection.aws_to_onprem_vpn.id
}

output "onprem_router_public_ip" {
  description = "Public IP of the On-Premises Router (for CGW configuration)"
  value       = aws_instance.onprem_router.public_ip
}

output "onprem_router_private_ip" {
  description = "Private IP of the On-Premises Router"
  value       = aws_instance.onprem_router.private_ip
}

output "vpn_tunnel_details" {
  description = "Details for configuring the on-premises VPN device"
  value = [
    for tunnel in aws_vpn_connection.aws_to_onprem_vpn.tunnel1, aws_vpn_connection.aws_to_onprem_vpn.tunnel2 : {
      vpn_gateway_ip = tunnel.vpn_gateway_ip
      pre_shared_key = tunnel.pre_shared_key
      outside_ip_address = tunnel.outside_ip_address
      bgp_asn = tunnel.bgp_asn
      bgp_holdtime = tunnel.bgp_holdtime
    }
  ]
}