# ========================================
# RANDOM PASSWORD para RDS
# ========================================
resource "random_password" "aurora_password" {
  length  = 16
  special = true
}

# ========================================
# SECRETS MANAGER - Almacenar credenciales
# ========================================
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name                    = "aurora/educloud-credentials"
  recovery_window_in_days = 0 # Para desarrollo; usar 7-30 en producción

  tags = {
    Name = "aurora-educloud-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "aurora_credentials" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.aurora_password.result
    engine   = "mysql"
    host     = aws_db_instance.aurora.address
    port     = 3306
    dbname   = var.database_name
  })
}

# ========================================
# DB SUBNET GROUP
# ========================================
resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "aurora-db-subnet-group"
  }
}

# ========================================
# SECURITY GROUP para RDS
# ========================================
resource "aws_security_group" "aurora" {
  name        = "rds-mysql-sg"
  description = "Security group for RDS MySQL database"
  vpc_id      = var.vpc_id

  # Permitir tráfico MySQL desde API ECS tasks
  ingress {
    description     = "MySQL from API ECS tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.api_security_group_id]
  }

  # Salida: permitir todo el tráfico saliente
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-mysql-security-group"
  }
}

# ========================================
# IAM ROLE REFERENCE
# ========================================
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ========================================
# RDS MYSQL INSTANCE (Compatible con AWS Academy)
# ========================================
resource "aws_db_instance" "aurora" {
  identifier           = "educloud-mysql-db"
  engine               = "mysql"
  engine_version       = "8.0.43"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  storage_encrypted    = true

  db_name  = var.database_name
  username = var.master_username
  password = random_password.aurora_password.result

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
  publicly_accessible    = false

  # Backup configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  # Maintenance
  maintenance_window = "sun:04:00-sun:05:00"

  # Monitoring
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  monitoring_interval             = 0  # Desactivar enhanced monitoring (no disponible en AWS Academy)

  # Skip final snapshot para desarrollo (cambiar en producción)
  skip_final_snapshot = true

  # Performance
  auto_minor_version_upgrade = true
  deletion_protection        = false

  tags = {
    Name = "educloud-mysql-database"
  }
}

# ========================================
# CLOUDWATCH ALARMS
# ========================================

# Alarma: CPU alto
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.aurora.identifier
  }

  tags = {
    Name = "rds-cpu-alarm"
  }
}

# Alarma: Conexiones de base de datos
resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  alarm_name          = "rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS database connections"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.aurora.identifier
  }

  tags = {
    Name = "rds-connections-alarm"
  }
}

# ========================================
# OUTPUTS
# ========================================
output "aurora_cluster_endpoint" {
  description = "RDS instance endpoint (writer)"
  value       = aws_db_instance.aurora.address
}

output "aurora_reader_endpoint" {
  description = "RDS reader endpoint (same as writer for single instance)"
  value       = aws_db_instance.aurora.address
}

output "aurora_port" {
  description = "RDS database port"
  value       = aws_db_instance.aurora.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_db_instance.aurora.db_name
}

output "master_username" {
  description = "Master username"
  value       = aws_db_instance.aurora.username
  sensitive   = true
}

output "secret_arn" {
  description = "ARN of the secret containing database credentials"
  value       = aws_secretsmanager_secret.aurora_credentials.arn
}

output "aurora_security_group_id" {
  description = "Security group ID of RDS"
  value       = aws_security_group.aurora.id
}
