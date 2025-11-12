# ========================================
# DATA SOURCES
# ========================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ========================================
# SECURITY GROUP para Nextcloud
# ========================================
resource "aws_security_group" "nextcloud" {
  name        = "nextcloud-sg"
  description = "Security group for Nextcloud - only accessible from VPC"
  vpc_id      = var.vpc_id

  # HTTP desde la VPC (Wireguard conectado)
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTPS desde la VPC
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Permitir todo el tráfico saliente
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nextcloud-security-group"
  }
}

# ========================================
# EC2 INSTANCE con Nextcloud
# ========================================
resource "aws_instance" "nextcloud" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.nextcloud.id]
  iam_instance_profile   = "LabInstanceProfile"
  key_name               = "vockey"

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Actualizar sistema
    apt-get update
    apt-get upgrade -y

    # Instalar Docker
    apt-get install -y docker.io docker-compose
    systemctl enable docker
    systemctl start docker

    # Crear directorio para Nextcloud
    mkdir -p /opt/nextcloud

    # Obtener credenciales de instancia para S3
    export AWS_REGION=us-east-1

    # Crear docker-compose.yml
    cat > /opt/nextcloud/docker-compose.yml <<'COMPOSE'
    version: "3.8"
    services:
      nextcloud:
        image: nextcloud:latest
        container_name: nextcloud
        environment:
          - NEXTCLOUD_ADMIN_USER=admin
          - NEXTCLOUD_ADMIN_PASSWORD=AdminPassword123!
          - NEXTCLOUD_TRUSTED_DOMAINS=10.0.0.0/16
        ports:
          - 80:80
        volumes:
          - nextcloud_data:/var/www/html
        restart: unless-stopped

    volumes:
      nextcloud_data:
    COMPOSE

    # Iniciar Nextcloud
    cd /opt/nextcloud
    docker-compose up -d

    # Esperar a que Nextcloud esté listo
    echo "Esperando a que Nextcloud se inicialice..."
    sleep 90

    # Configurar S3 como almacenamiento primario
    cat > /tmp/s3config.php <<S3CONFIG
    <?php
    \$CONFIG = array(
      'objectstore' => array(
        'class' => '\OC\Files\ObjectStore\S3',
        'arguments' => array(
          'bucket' => '${var.s3_bucket_name}',
          'autocreate' => false,
          'key' => '',
          'secret' => '',
          'use_ssl' => true,
          'region' => 'us-east-1',
          'use_path_style' => false,
          'sse_c_key' => '',
          'use_aws_iam_role' => true
        ),
      ),
    );
    S3CONFIG

    # Copiar configuración al contenedor
    docker cp /tmp/s3config.php nextcloud:/var/www/html/config/s3.config.php

    # Reiniciar Nextcloud para aplicar configuración S3
    docker restart nextcloud

    echo "Nextcloud configurado con S3 como almacenamiento"
  EOF
  )

  tags = {
    Name = "nextcloud-server"
  }
}

# ========================================
# OUTPUTS
# ========================================
output "nextcloud_private_ip" {
  description = "Private IP of Nextcloud server"
  value       = aws_instance.nextcloud.private_ip
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.nextcloud.id
}

output "nextcloud_security_group_id" {
  description = "Security group ID for Nextcloud"
  value       = aws_security_group.nextcloud.id
}

output "connection_info" {
  description = "How to access Nextcloud"
  value       = "Connect to VPN and access http://${aws_instance.nextcloud.private_ip} - User: admin, Password: AdminPassword123!"
}
