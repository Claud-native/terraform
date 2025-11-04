# ==========================
# Variables
# ==========================
variable "execution_role_arn" {
  description = "ARN del rol de ejecución ECS (ya existente)"
  type        = string
  default     = "arn:aws:iam::704518799449:role/LabRole"
}

variable "task_role_arn" {
  description = "ARN del rol que los containers ECS usarán (ya existente)"
  type        = string
  default     = "arn:aws:iam::704518799449:role/LabRole" 
}

variable "private_subnet_id" {
  description = "ID de la subnet privada"
  type        = string
}

variable "private_sg_id" {
  description = "ID del Security Group privado"
  type        = string
}

variable "mariadb_image" {
  description = "Imagen de MariaDB"
  type        = string
  default     = "pina123/my-mariadb:latest"
}

variable "nextcloud_image" {
  description = "Imagen de Nextcloud"
  type        = string
  default     = "pina123/my-mariadb:latest"
}

variable "db_root_password" {
  description = "Contraseña root de MariaDB"
  type        = string
  default     = "Almi1234"
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "nextcloud"
}

variable "db_user" {
  description = "Usuario de la base de datos"
  type        = string
  default     = "Almi"
}

variable "db_password" {
  description = "Contraseña del usuario de la base de datos"
  type        = string
  default     = "Almi1234"
}

variable "nextcloud_admin_user" {
  description = "Usuario administrador de Nextcloud"
  type        = string
  default     = "Almi"
}

variable "nextcloud_admin_password" {
  description = "Contraseña administrador de Nextcloud"
  type        = string
  default     = "Almi1234"
}

variable "region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}