variable "vpc_id" {
  description = "VPC id where WireGuard will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet id to host the WireGuard server (needs map_public_ip_on_launch=true)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the WireGuard server"
  type        = string
  default     = "t3.micro"
}

variable "ami" {
  description = "AMI id to use for the WireGuard server (Amazon Linux 2 recommended)"
  type        = string
  default     = "ami-0c02fb55956c7d316" # Amazon Linux 2 in us-east-1 (may change)
}

variable "key_name" {
  description = "EC2 key pair name for SSH access (optional, set to empty string to skip)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the WireGuard server (for admin). Use your IP in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "wireguard_port" {
  description = "UDP port WireGuard will listen on"
  type        = number
  default     = 51820
}
