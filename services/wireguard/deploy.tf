locals {
  wg_iface = "wg0"
}

resource "aws_security_group" "wireguard_sg" {
  name        = "wireguard-sg"
  description = "Allow WireGuard UDP and SSH"
  vpc_id      = var.vpc_id

  ingress {
    description = "WireGuard UDP"
    from_port   = var.wireguard_port
    to_port     = var.wireguard_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wireguard-security-group"
  }
}

# Elastic IP for the WireGuard instance (so public IP is stable)
resource "aws_eip" "wg_eip" {
  domain = "vpc"
}

resource "aws_instance" "wireguard" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.wireguard_sg.id]
  associate_public_ip_address = true
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    iface       = local.wg_iface
    listen_port = tostring(var.wireguard_port)
  })

  tags = {
    Name = "wireguard-server"
  }

  provisioner "local-exec" {
    command = "echo WireGuard instance created: ${self.public_ip}"
  }

  depends_on = [aws_eip.wg_eip]
}

# Associate EIP to the instance
resource "aws_eip_association" "wg_eip_assoc" {
  instance_id   = aws_instance.wireguard.id
  allocation_id = aws_eip.wg_eip.id
}
