# ==========================
# Variables
# ==========================

# Roles: con AWS Academy/LabRole puedes dejarlos así
variable "execution_role_arn" {
  description = "ARN del rol de ejecución ECS (pull de imagen y logs)"
  type        = string
  default     = "arn:aws:iam::891377069738:role/LabRole"
}

variable "task_role_arn" {
  description = "ARN del rol que usan los contenedores (permisos runtime: S3, etc.)"
  type        = string
  default     = "arn:aws:iam::891377069738:role/LabRole"
}

# Si NO usas LabRole admin y quieres adjuntar policies, pon true
variable "attach_policies" {
  description = "Adjuntar policies IAM (S3/Execution) a los roles dados"
  type        = bool
  default     = false
}

# Networking
variable "private_subnet_id" {
  description = "ID de la subnet privada donde corre ECS"
  type        = string
}

variable "private_sg_id" {
  description = "ID del Security Group para ECS en subred privada"
  type        = string
}

# Imágenes
variable "mariadb_image" {
  description = "Imagen de MariaDB (ej. mariadb:10.11)"
  type        = string
  default     = "mariadb:10.11"
}

variable "nextcloud_image" {
  description = "Imagen de Nextcloud (ej. nextcloud:29-apache)"
  type        = string
  default     = "nextcloud:29-apache"
}

# Credenciales DB (mejor en Secrets Manager/SSM en prod)
variable "db_root_password" {
  description = "Contraseña root de MariaDB"
  type        = string
  sensitive   = true
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
  sensitive   = true
  default     = "Almi1234"
}

# Admin Nextcloud (mejor en Secrets en prod)
variable "nextcloud_admin_user" {
  description = "Usuario administrador de Nextcloud"
  type        = string
  default     = "Almi"
}

variable "nextcloud_admin_password" {
  description = "Contraseña administrador de Nextcloud"
  type        = string
  sensitive   = true
  default     = "Almi1234"
}

# Región
variable "region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}
