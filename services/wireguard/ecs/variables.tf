variable "vpc_id" {
  description = "VPC id where ECS instances will run"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet ids for the ASG"
  type        = list(string)
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into ECS instances"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 1
}

variable "wireguard_port" {
  type    = number
  default = 51820
}

variable "container_image" {
  description = "Docker image for WireGuard (e.g. ghcr.io/linuxserver/wireguard:latest)"
  type        = string
  default     = "ghcr.io/linuxserver/wireguard:latest"
}

variable "create_iam" {
  description = "Whether to create IAM role and instance profile for ECS instances. Set to false to use an existing default instance profile."
  type        = bool
  default     = false
}

variable "instance_profile_name" {
  description = "Name of an existing IAM instance profile to use for ECS instances. If empty and create_iam=false, the launch template will not set an instance profile and you must ensure instances have appropriate profile via another mechanism."
  type        = string
  default     = ""
}
