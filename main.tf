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

# Subnet Pública
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
    Type = "Public"
  }
}

# Subnet Privada
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
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
  subnet_id     = aws_subnet.public.id

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

# Asociación Route Table - Subnet Pública
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Asociación Route Table - Subnet Privada
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ========================================
# SECURITY GROUPS
# ========================================

# Security Group Público
resource "aws_security_group" "public" {
  name        = "public-sg"
  description = "Security group for public subnet - allows HTTP, HTTPS and SSH from internet"
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

# Modules
module "waf" {
  source = "./services/waf"
}

# ========================================
# Wireguard EC2 Module
# ========================================
module "wireguard" {
  source        = "./services/wireguard"
  vpc_id        = aws_vpc.main.id
  ami_id        = "ami-0360c520857e3138f"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  sg_id         = aws_security_group.public.id  
  name          = "wg-ec2"
}

# ========================================
# Nextcloud ECS Module
# ========================================

# Módulo Nextcloud
module "nextcloud" {
  source = "./services/nextcloud"

  task_role_arn      = "arn:aws:iam::637423601326:role/LabRole"

  private_subnet_id  = aws_subnet.private.id
  private_sg_id      = aws_security_group.private.id

  mariadb_image      = "my-mariadb:latest"
  nextcloud_image    = "my-nextcloud-s3:latest"

  db_name              = "nextcloud"
  db_user              = "Almi"
  db_root_password      = "Almi1234"
  db_password           = "Almi1234"
  nextcloud_admin_user  = "Almi"
  nextcloud_admin_password = "Almi1234"
  region                = "us-east-1"
}



