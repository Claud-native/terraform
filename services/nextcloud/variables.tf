# Roles (con AWS Academy/LabRole puedes dejarlos así)
variable "execution_role_arn" {
  description = "ARN del rol de ejecución ECS (pull de imagen y logs)"
  type        = string
  default     = "arn:aws:iam::891377069738:role/LabRole"
}

variable "task_role_arn" {
  description = "ARN del rol que usan los contenedores (permisos runtime: S3, EFS, etc.)"
  type        = string
  default     = "arn:aws:iam::891377069738:role/LabRole"
}

# Si NO usas LabRole admin y quieres adjuntar policies mínimas, pon true
variable "attach_policies" {
  description = "Adjuntar policies IAM (S3/Execution) a los roles dados"
  type        = bool
  default     = false
}

# Networking
variable "vpc_id" {
  description = "ID del VPC en el que están las subnets y el SG"
  type        = string
}
variable "private_subnet_id" {
  description = "ID de la subnet privada donde corre ECS/EFS"
  type        = string
}
variable "private_sg_id" {
  description = "ID del Security Group de tareas ECS (debe poder salir a 0.0.0.0/0)"
  type        = string
}

# Imágenes
variable "mariadb_image" {
  description = "Imagen MariaDB"
  type        = string
  default     = "mariadb:10.11"
}
variable "nextcloud_image" {
  description = "Imagen Nextcloud"
  type        = string
  default     = "nextcloud:29-apache"
}

# Credenciales DB (demo; en prod Secrets Manager/SSM)
variable "db_root_password" {
  description = "Contraseña root de MariaDB"
  type        = string
  sensitive   = true
}
variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}
variable "db_user" {
  description = "Usuario de la base de datos"
  type        = string
}
variable "db_password" {
  description = "Contraseña del usuario de la base de datos"
  type        = string
  sensitive   = true
}

# Admin Nextcloud
variable "nextcloud_admin_user" {
  description = "Usuario administrador de Nextcloud"
  type        = string
}
variable "nextcloud_admin_password" {
  description = "Contraseña administrador de Nextcloud"
  type        = string
  sensitive   = true
}

# Región
variable "region" {
  description = "Región AWS"
  type        = string
  default     = "us-east-1"
}
