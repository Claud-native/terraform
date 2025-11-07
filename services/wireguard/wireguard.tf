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
# SECURITY GROUP para Wireguard EC2
# ========================================
resource "aws_security_group" "wireguard" {
  name        = "wireguard-sg"
  description = "Security group for Wireguard VPN - allows UDP 51820 from internet"
  vpc_id      = var.vpc_id

  # Puerto Wireguard desde internet
  ingress {
    description = "Wireguard VPN from internet"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH para administración
  ingress {
    description = "SSH from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "wireguard-security-group"
  }
}

# ========================================
# EC2 INSTANCE con Wireguard
# ========================================
resource "aws_instance" "wireguard" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.wireguard.id]
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

    # Crear directorio para Wireguard
    mkdir -p /opt/wireguard/config

    # Obtener IP pública
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

    # Crear docker-compose.yml
    cat > /opt/wireguard/docker-compose.yml <<'COMPOSE'
    version: "3.8"
    services:
      wireguard:
        image: linuxserver/wireguard:latest
        container_name: wireguard
        cap_add:
          - NET_ADMIN
          - SYS_MODULE
        environment:
          - PUID=1000
          - PGID=1000
          - TZ=Europe/Madrid
          - SERVERURL=$PUBLIC_IP
          - SERVERPORT=51820
          - PEERS=5
          - PEERDNS=10.0.0.2
          - INTERNAL_SUBNET=10.13.13.0
          - ALLOWEDIPS=10.0.0.0/16
          - LOG_CONFS=true
        volumes:
          - /opt/wireguard/config:/config
          - /lib/modules:/lib/modules
        ports:
          - 51820:51820/udp
        sysctls:
          - net.ipv4.conf.all.src_valid_mark=1
        restart: unless-stopped
    COMPOSE

    # Iniciar Wireguard
    cd /opt/wireguard
    docker-compose up -d

    # Esperar a que se generen las configuraciones
    sleep 30
  EOF
  )

  tags = {
    Name = "wireguard-vpn-server"
  }
}

# ========================================
# OUTPUTS
# ========================================
output "wireguard_public_ip" {
  description = "Public IP of Wireguard VPN server"
  value       = aws_instance.wireguard.public_ip
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.wireguard.id
}

output "wireguard_security_group_id" {
  description = "Security group ID for Wireguard VPN"
  value       = aws_security_group.wireguard.id
}

output "connection_info" {
  description = "How to get Wireguard client configs"
  value       = "SSH to ${aws_instance.wireguard.public_ip} and check /opt/wireguard/config/peer* for QR codes and configs"
}
