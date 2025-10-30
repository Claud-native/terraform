# ========================================
# VARIABLES - AURORA MODULE
# ========================================

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Aurora"
  type        = list(string)
}

variable "api_security_group_id" {
  description = "Security group ID of the API ECS tasks"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "educloud"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}
