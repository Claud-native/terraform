resource "aws_instance" "wg" {
  ami                    = var.ami_id          # Ubuntu/Debian/etc. soportado por el script
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.wireguard_sg.id]
  key_name               = "vockey"   

  # Ejecuta el script externo en el boot
  user_data = file("${path.module}/scripts/wireguard-userdata.sh")

  tags = {
    Name = var.name
  }
}


resource "aws_security_group" "wireguard_sg" {
  name        = "wireguard-sg"
  description = "WireGuard (UDP 51820) y SSH"
  vpc_id      = var.vpc_id

  # WireGuard
  ingress {
    description = "WireGuard VPN"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH opcional (reemplaza por tu IP)
  ingress {
    description = "SSH admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Todo salida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
