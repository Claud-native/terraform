terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# ========================================
# VPC
# ========================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# ========================================
# SUBNETS
# ========================================

# Subnet Pública 1 (AZ: us-east-1a)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
    Type = "Public"
  }
}

# Subnet Pública 2 (AZ: us-east-1b)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
    Type = "Public"
  }
}

# Subnet Privada 1 (AZ: us-east-1a)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-1"
    Type = "Private"
  }
}

# Subnet Privada 2 (AZ: us-east-1b) - Para Multi-AZ Aurora
resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-2"
    Type = "Private"
  }
}

# ========================================
# INTERNET GATEWAY (para subnet pública)
# ========================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# ========================================
# ELASTIC IP (para NAT Gateway)
# ========================================
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ========================================
# NAT GATEWAY (para subnet privada)
# ========================================
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "main-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ========================================
# ROUTE TABLES
# ========================================

# Route Table para Subnet Pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Route Table para Subnet Privada
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Asociación Route Table - Subnet Pública 1
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Asociación Route Table - Subnet Pública 2
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Asociación Route Table - Subnet Privada 1
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Asociación Route Table - Subnet Privada 2
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ========================================
# SECURITY GROUPS
# ========================================

# Security Group Público
resource "aws_security_group" "public" {
  name        = "public-sg"
  description = "Security group for public subnet - allows HTTP, HTTPS, SSH and Wireguard from internet"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (mejor limitar a tu IP específica en producción)
  ingress {
    description = "SSH from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Wireguard VPN
  ingress {
    description = "Wireguard VPN from internet"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Salida: permitir todo el tráfico saliente
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-security-group"
  }
}

# Security Group Privado
resource "aws_security_group" "private" {
  name        = "private-sg"
  description = "Security group for private subnet - only allows traffic from public subnet"
  vpc_id      = aws_vpc.main.id

  # Permitir tráfico desde la subnet pública
  ingress {
    description     = "All traffic from public subnet"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.public.id]
  }

  # Permitir tráfico interno dentro de la subnet privada
  ingress {
    description = "All traffic from private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Salida: permitir todo el tráfico saliente (a través del NAT Gateway)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-security-group"
  }
}

# ========================================
# MÓDULOS DE SERVICIOS PRINCIPALES
# ========================================

# WAF para protección web
module "waf" {
  source = "./services/waf"
}

# API Backend
module "api" {
  source = "./services/api"

  vpc_id                    = aws_vpc.main.id
  private_subnet_ids        = [aws_subnet.private.id, aws_subnet.private_2.id]
  security_group_id         = aws_security_group.private.id
  public_subnet_ids         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  public_security_group_id  = aws_security_group.public.id

  # Database connection parameters
  db_endpoint    = module.aurora.aurora_cluster_endpoint
  db_port        = module.aurora.aurora_port
  db_name        = module.aurora.database_name
  db_username    = module.aurora.master_username
  db_secret_arn  = module.aurora.secret_arn
  jwt_secret_arn = module.aurora.jwt_secret_arn

  # CORS configuration - URL del balanceador web
  cors_web_url   = "http://${module.web.alb_dns_name}"
}

# Base de datos Aurora
module "aurora" {
  source = "./services/aurora"

  vpc_id                 = aws_vpc.main.id
  private_subnet_ids     = [aws_subnet.private.id, aws_subnet.private_2.id]
  api_security_group_id  = module.api.api_security_group_id
  database_name          = "educloud"
  master_username        = "admin"
}

# Frontend Web
module "web" {
  source = "./services/web"

  vpc_id             = aws_vpc.main.id
  public_subnet_ids  = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_group_id  = aws_security_group.public.id
  api_url            = module.api.alb_dns_name
}

# ========================================
# ASOCIAR WAF CON ALB
# ========================================
resource "aws_wafv2_web_acl_association" "web_alb" {
  resource_arn = module.web.alb_arn
  web_acl_arn  = module.waf.waf_web_acl_arn
}

# ========================================
# DATA SOURCES
# ========================================
data "aws_caller_identity" "current" {}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ========================================
# MÓDULOS DE NUEVOS SERVICIOS
# ========================================

# Módulo S3 para almacenamiento de Nextcloud
module "s3" {
  source = "./services/s3"

  vpc_id          = aws_vpc.main.id
  route_table_ids = [aws_route_table.private.id]
  account_id      = data.aws_caller_identity.current.account_id
  lab_role_arn    = data.aws_iam_role.lab_role.arn
}

# Módulo Wireguard VPN en subred pública
module "wireguard" {
  source = "./services/wireguard"

  vpc_id             = aws_vpc.main.id
  public_subnet_ids  = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# Módulo Nextcloud en subred privada
module "nextcloud" {
  source = "./services/nextcloud"

  vpc_id             = aws_vpc.main.id
  private_subnet_ids = [aws_subnet.private.id, aws_subnet.private_2.id]
  s3_bucket_name     = module.s3.bucket_name

  depends_on = [module.s3]
}

# ========================================
# OUTPUTS - URLs PÚBLICAS
# ========================================
output "web_url" {
  description = "URL pública de la aplicación web"
  value       = "http://${module.web.alb_dns_name}"
}

output "api_url" {
  description = "URL pública de la API"
  value       = "http://${module.api.alb_dns_name}"
}

output "database_endpoint" {
  description = "Endpoint de la base de datos Aurora (interno)"
  value       = module.aurora.aurora_cluster_endpoint
  sensitive   = true
}

output "wireguard_info" {
  description = "Información del servidor Wireguard VPN"
  value       = "Wireguard VPN desplegado. Conecta y accede a los recursos internos (puerto UDP 51820)"
}

output "nextcloud_info" {
  description = "Información de Nextcloud"
  value       = "Nextcloud accesible solo desde VPN en red privada (10.0.2.0/24 y 10.0.4.0/24)"
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 para Nextcloud"
  value       = module.s3.bucket_name
}