resource "aws_ecs_cluster" "wg_cluster" {
  name = "wg-cluster"
}

resource "aws_security_group" "ecs_wireguard_sg" {
  name        = "ecs-wireguard-sg"
  description = "Allow WireGuard and SSH"
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

  tags = { Name = "ecs-wireguard-sg" }
}
