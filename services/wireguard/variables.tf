variable "vpc_id" {
  description = "VPC id where to launch the WireGuard EC2"
  type        = string
}

variable "public_subnet_id" {
  description = "A public subnet id to place the EC2 into"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Optional SSH key name to attach to the instance"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "wireguard_port" {
  description = "UDP port for WireGuard"
  type        = number
  default     = 51820
}

variable "instance_profile_name" {
  description = "Optional existing instance profile name to attach (leave empty to not set)"
  type        = string
  default     = ""
}

variable "ubuntu_ami_owner" {
  description = "AMI owner for the Ubuntu AMI to use"
  type        = string
  default     = "099720109477"
}

variable "ubuntu_ami_name" {
  description = "AMI name filter for Ubuntu Jammy"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}
