# ========================================
# VARIABLES - API MODULE
# ========================================

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the private security group"
  type        = string
}

variable "public_security_group_id" {
  description = "ID of the public security group for ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "db_endpoint" {
  description = "Aurora database endpoint"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Aurora database port"
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "educloud"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "db_secret_arn" {
  description = "ARN of the secret containing database credentials"
  type        = string
  default     = ""
}

variable "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  type        = string
  default     = ""
}

variable "rsa_private_key_arn" {
  description = "ARN of the RSA private key secret"
  type        = string
  default     = ""
}

variable "cors_web_url" {
  description = "URL del balanceador de carga web para CORS"
  type        = string
  default     = ""
}
