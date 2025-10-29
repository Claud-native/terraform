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
    Name        = "main-vpc"
    Environment = "production"
  }
}

# ========================================
# SUBNETS - Multi-AZ para Aurora
# ========================================

# Subnets Públicas
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "public-subnet-1a"
    Type        = "Public"
    Environment = "production"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "public-subnet-1b"
    Type        = "Public"
    Environment = "production"
  }
}

# Subnets Privadas (para Aurora y ECS)
resource "aws_subnet" "private_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "private-subnet-1a"
    Type        = "Private"
    Environment = "production"
  }
}

resource "aws_subnet" "private_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name        = "private-subnet-1b"
    Type        = "Private"
    Environment = "production"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = false

  tags = {
    Name        = "private-subnet-1c"
    Type        = "Private"
    Environment = "production"
  }
}

# ========================================
# INTERNET GATEWAY (para subnets públicas)
# ========================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "main-igw"
    Environment = "production"
  }
}

# ========================================
# ELASTIC IPs (para NAT Gateways)
# ========================================
resource "aws_eip" "nat_1a" {
  domain = "vpc"

  tags = {
    Name        = "nat-eip-1a"
    Environment = "production"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat_1b" {
  domain = "vpc"

  tags = {
    Name        = "nat-eip-1b"
    Environment = "production"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ========================================
# NAT GATEWAYS (para subnets privadas)
# ========================================
resource "aws_nat_gateway" "nat_1a" {
  allocation_id = aws_eip.nat_1a.id
  subnet_id     = aws_subnet.public_1a.id

  tags = {
    Name        = "nat-gateway-1a"
    Environment = "production"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_1b" {
  allocation_id = aws_eip.nat_1b.id
  subnet_id     = aws_subnet.public_1b.id

  tags = {
    Name        = "nat-gateway-1b"
    Environment = "production"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ========================================
# ROUTE TABLES
# ========================================

# Route Table para Subnets Públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "public-route-table"
    Environment = "production"
  }
}

# Route Tables para Subnets Privadas (una por AZ para alta disponibilidad)
resource "aws_route_table" "private_1a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1a.id
  }

  tags = {
    Name        = "private-route-table-1a"
    Environment = "production"
  }
}

resource "aws_route_table" "private_1b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1b.id
  }

  tags = {
    Name        = "private-route-table-1b"
    Environment = "production"
  }
}

resource "aws_route_table" "private_1c" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1b.id  # Usa NAT de 1b
  }

  tags = {
    Name        = "private-route-table-1c"
    Environment = "production"
  }
}

# Asociaciones Route Tables - Subnets Públicas
resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

# Asociaciones Route Tables - Subnets Privadas
resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_1a.id
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private_1b.id
}

resource "aws_route_table_association" "private_1c" {
  subnet_id      = aws_subnet.private_1c.id
  route_table_id = aws_route_table.private_1c.id
}

# ========================================
# SECURITY GROUPS (Los que ya tenías)
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
    Name        = "public-security-group"
    Environment = "production"
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
    Name        = "private-security-group"
    Environment = "production"
  }
}

# ========================================
# MÓDULOS
# ========================================

# WAF
module "waf" {
  source = "./services/waf"
}

# Aurora PostgreSQL
module "aurora" {
  source = "./services/aurora"

  vpc_id                       = aws_vpc.main.id
  private_subnet_ids           = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1b.id,
    aws_subnet.private_1c.id
  ]
  allowed_security_group_ids   = []  # Se agregará el SG de ECS después
  database_name                = "educloud"
  master_username              = "masteruser"
  environment                  = "production"
  instance_class               = "db.r6g.large"
}

# ECR Repository para Backend
resource "aws_ecr_repository" "educloud_backend" {
  name                 = "educloud-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "educloud-backend"
    Environment = "production"
  }
}

# ECS Fargate
module "ecs" {
  source = "./services/ecs"

  vpc_id                = aws_vpc.main.id
  public_subnet_ids     = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1b.id
  ]
  private_subnet_ids    = [
    aws_subnet.private_1a.id,
    aws_subnet.private_1b.id,
    aws_subnet.private_1c.id
  ]
  aurora_security_group_id   = module.aurora.security_group_id
  db_credentials_secret_arn  = module.aurora.app_credentials_secret_arn
  jwt_secret_arn             = module.aurora.jwt_secret_arn
  environment                = "production"
  cors_allowed_origins       = "https://educloud.com,https://www.educloud.com"
  ecs_task_cpu               = 1024
  ecs_task_memory            = 2048
  desired_count              = 3
  ecr_image_url              = "${aws_ecr_repository.educloud_backend.repository_url}:latest"

  depends_on = [module.aurora]
}

# ========================================
# OUTPUTS
# ========================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "aurora_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.aurora.cluster_endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = module.aurora.cluster_reader_endpoint
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ecs.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for backend"
  value       = aws_ecr_repository.educloud_backend.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.ecs_cluster_name
}

output "app_password" {
  description = "Application user password for Aurora (SENSITIVE)"
  value       = module.aurora.app_password
  sensitive   = true
}
