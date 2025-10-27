data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ubuntu_ami_owner]
  filter {
    name   = "name"
    values = [var.ubuntu_ami_name]
  }
}

resource "aws_security_group" "wg_sg" {
  name        = "wg-sg"
  description = "Security group for WireGuard EC2"
  vpc_id      = var.vpc_id

  ingress {
    description = "WireGuard UDP"
    from_port   = var.wireguard_port
    to_port     = var.wireguard_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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

  tags = { Name = "wg-sg" }
}

resource "aws_instance" "wg" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.wg_sg.id]
  key_name               = var.key_name != "" ? var.key_name : null
  user_data              = templatefile("${path.module}/user_data.sh.tpl", { wireguard_port = tostring(var.wireguard_port) })

  iam_instance_profile = var.instance_profile_name != "" ? var.instance_profile_name : null

  tags = { Name = "wireguard-server" }
}

resource "aws_eip" "wg_eip" {
  instance = aws_instance.wg.id
  domain   = "vpc"
}
