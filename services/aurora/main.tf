# ========================================
# Amazon Aurora PostgreSQL Cluster
# Compatible con EduCloud Backend
# ========================================

# ========================================
# Variables para Aurora
# ========================================
variable "vpc_id" {
  description = "VPC ID where Aurora will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Aurora"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups that can access Aurora (ECS tasks)"
  type        = list(string)
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "educloud"
}

variable "master_username" {
  description = "Master username for Aurora"
  type        = string
  default     = "masteruser"
  sensitive   = true
}

variable "environment" {
  description = "Environment name (development, production)"
  type        = string
  default     = "production"
}

variable "instance_class" {
  description = "Instance class for Aurora"
  type        = string
  default     = "db.r6g.large"
}

# ========================================
# Subnet Group para Aurora
# ========================================
resource "aws_db_subnet_group" "aurora" {
  name       = "educloud-aurora-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "educloud-aurora-subnet-group"
    Environment = var.environment
  }
}

# ========================================
# Security Group para Aurora
# ========================================
resource "aws_security_group" "aurora" {
  name        = "educloud-aurora-sg"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = var.vpc_id

  # PostgreSQL desde ECS Tasks
  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  # Egress - permitir todo el tráfico saliente
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "educloud-aurora-sg"
    Environment = var.environment
  }
}

# ========================================
# KMS Key para Encriptación
# ========================================
resource "aws_kms_key" "aurora" {
  description             = "KMS key for Aurora encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "educloud-aurora-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/educloud-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

# ========================================
# Passwords Aleatorios
# ========================================
resource "random_password" "master_password" {
  length  = 32
  special = true
  # Caracteres que Aurora PostgreSQL acepta
  override_special = "!#$%&*()-_=+[]{}:?"
}

resource "random_password" "app_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

# ========================================
# Aurora PostgreSQL Cluster
# ========================================
resource "aws_rds_cluster" "educloud" {
  cluster_identifier      = "educloud-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "15.4"
  database_name           = var.database_name
  master_username         = var.master_username
  master_password         = random_password.master_password.result

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # Multi-AZ para alta disponibilidad
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Backup y Mantenimiento
  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  # Seguridad
  storage_encrypted = true
  kms_key_id        = aws_kms_key.aurora.arn

  # Performance y Logging
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Protección contra eliminación accidental
  skip_final_snapshot       = false
  final_snapshot_identifier = "educloud-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection       = true

  # Apply changes immediately (cuidado en producción)
  apply_immediately = false

  tags = {
    Name        = "educloud-aurora-cluster"
    Environment = var.environment
  }
}

# ========================================
# Aurora Instances
# ========================================

# Writer Instance
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "educloud-writer"
  cluster_identifier = aws_rds_cluster.educloud.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.educloud.engine
  engine_version     = aws_rds_cluster.educloud.engine_version

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.aurora.arn
  performance_insights_retention_period = 7

  # Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = {
    Name        = "educloud-writer"
    Environment = var.environment
    Role        = "writer"
  }
}

# Reader Instance (para alta disponibilidad y lectura escalable)
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "educloud-reader"
  cluster_identifier = aws_rds_cluster.educloud.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.educloud.engine
  engine_version     = aws_rds_cluster.educloud.engine_version

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.aurora.arn
  performance_insights_retention_period = 7

  # Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = {
    Name        = "educloud-reader"
    Environment = var.environment
    Role        = "reader"
  }
}

# ========================================
# IAM Role para Enhanced Monitoring
# ========================================
resource "aws_iam_role" "rds_monitoring" {
  name = "educloud-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "educloud-rds-monitoring-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ========================================
# Secrets Manager para Credentials
# ========================================

# Master Credentials
resource "aws_secretsmanager_secret" "db_master_credentials" {
  name        = "educloud/database/master-credentials"
  description = "Aurora PostgreSQL master credentials"

  tags = {
    Name        = "educloud-db-master-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_master_credentials" {
  secret_id = aws_secretsmanager_secret.db_master_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master_password.result
    host     = aws_rds_cluster.educloud.endpoint
    port     = 5432
    database = var.database_name
  })
}

# App Credentials (para backend Spring Boot)
resource "aws_secretsmanager_secret" "db_app_credentials" {
  name        = "educloud/database/app-credentials"
  description = "Aurora PostgreSQL application credentials for EduCloud backend"

  tags = {
    Name        = "educloud-db-app-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_app_credentials" {
  secret_id = aws_secretsmanager_secret.db_app_credentials.id
  secret_string = jsonencode({
    username = "educloud_app"
    password = random_password.app_password.result
    host     = aws_rds_cluster.educloud.endpoint
    port     = 5432
    database = var.database_name
    url      = "jdbc:postgresql://${aws_rds_cluster.educloud.endpoint}:5432/${var.database_name}"
  })
}

# JWT Secret para backend
resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "educloud/jwt/secret"
  description = "JWT signing secret for EduCloud backend"

  tags = {
    Name        = "educloud-jwt-secret"
    Environment = var.environment
  }
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

# ========================================
# CloudWatch Alarms para Aurora
# ========================================

# High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_cpu_high" {
  alarm_name          = "educloud-aurora-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Aurora CPU utilization is too high"
  alarm_actions       = []  # Agregar SNS topic para notificaciones

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.educloud.cluster_identifier
  }
}

# High Connections Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_connections_high" {
  alarm_name          = "educloud-aurora-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Aurora connection count is too high"
  alarm_actions       = []  # Agregar SNS topic para notificaciones

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.educloud.cluster_identifier
  }
}

# ========================================
# Outputs
# ========================================
output "cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.educloud.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.educloud.reader_endpoint
}

output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.educloud.cluster_identifier
}

output "security_group_id" {
  description = "Security group ID for Aurora"
  value       = aws_security_group.aurora.id
}

output "app_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing app credentials"
  value       = aws_secretsmanager_secret.db_app_credentials.arn
}

output "jwt_secret_arn" {
  description = "ARN of the Secrets Manager secret containing JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "app_password" {
  description = "Application user password (sensitive)"
  value       = random_password.app_password.result
  sensitive   = true
}
