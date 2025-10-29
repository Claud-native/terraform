# ========================================
# ECS Fargate para EduCloud Backend
# ========================================

# ========================================
# Variables
# ========================================
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "aurora_security_group_id" {
  description = "Security group ID of Aurora cluster"
  type        = string
}

variable "db_credentials_secret_arn" {
  description = "ARN of Secrets Manager secret with DB credentials"
  type        = string
}

variable "jwt_secret_arn" {
  description = "ARN of Secrets Manager secret with JWT secret"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins (comma-separated)"
  type        = string
  default     = "https://educloud.com,https://www.educloud.com"
}

variable "ecs_task_cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 1024  # 1 vCPU
}

variable "ecs_task_memory" {
  description = "ECS task memory (MB)"
  type        = number
  default     = 2048  # 2 GB
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 3
}

variable "ecr_image_url" {
  description = "ECR image URL for the backend"
  type        = string
}

# ========================================
# ECS Cluster
# ========================================
resource "aws_ecs_cluster" "educloud" {
  name = "educloud-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "educloud-cluster"
    Environment = var.environment
  }
}

# ========================================
# CloudWatch Log Group
# ========================================
resource "aws_cloudwatch_log_group" "ecs_backend" {
  name              = "/ecs/educloud-backend"
  retention_in_days = 30

  tags = {
    Name        = "educloud-backend-logs"
    Environment = var.environment
  }
}

# ========================================
# IAM Roles
# ========================================

# ECS Task Execution Role (pull ECR, read Secrets Manager)
resource "aws_iam_role" "ecs_execution_role" {
  name = "educloud-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "educloud-ecs-execution-role"
    Environment = var.environment
  }
}

# Política para ECS Task Execution Role
resource "aws_iam_role_policy" "ecs_execution_policy" {
  name = "educloud-ecs-execution-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ecs_backend.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.db_credentials_secret_arn,
          var.jwt_secret_arn
        ]
      }
    ]
  })
}

# ECS Task Role (permisos que tiene la aplicación en runtime)
resource "aws_iam_role" "ecs_task_role" {
  name = "educloud-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "educloud-ecs-task-role"
    Environment = var.environment
  }
}

# Política para ECS Task Role (CloudWatch Metrics)
resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "educloud-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ecs_backend.arn}:*"
      }
    ]
  })
}

# ========================================
# Security Groups
# ========================================

# Security Group para ALB
resource "aws_security_group" "alb" {
  name        = "educloud-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "educloud-alb-sg"
    Environment = var.environment
  }
}

# Security Group para ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "educloud-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  # Permitir tráfico desde ALB
  ingress {
    description     = "Traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Egress
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "educloud-ecs-tasks-sg"
    Environment = var.environment
  }
}

# Regla para permitir que ECS Tasks accedan a Aurora
resource "aws_security_group_rule" "ecs_to_aurora" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = var.aurora_security_group_id
  description              = "Allow ECS tasks to access Aurora"
}

# ========================================
# Application Load Balancer
# ========================================
resource "aws_lb" "educloud" {
  name               = "educloud-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "educloud-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "educloud_backend" {
  name        = "educloud-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "educloud-backend-tg"
    Environment = var.environment
  }
}

# HTTP Listener (redirige a HTTPS en producción)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.educloud.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.educloud_backend.arn
  }

  # En producción, cambiar a redirect a HTTPS:
  # default_action {
  #   type = "redirect"
  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
}

# HTTPS Listener (descomentar cuando tengas certificado ACM)
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.educloud.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID"
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.educloud_backend.arn
#   }
# }

# ========================================
# ECS Task Definition
# ========================================
resource "aws_ecs_task_definition" "educloud_backend" {
  family                   = "educloud-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "educloud-backend"
      image     = var.ecr_image_url
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "production"
        },
        {
          name  = "SERVER_PORT"
          value = "8080"
        },
        {
          name  = "CORS_ALLOWED_ORIGINS"
          value = var.cors_allowed_origins
        },
        {
          name  = "JWT_EXPIRATION"
          value = "86400000"
        },
        {
          name  = "HIKARI_MAX_POOL_SIZE"
          value = "20"
        },
        {
          name  = "HIKARI_MIN_IDLE"
          value = "5"
        },
        {
          name  = "DDL_AUTO"
          value = "validate"
        },
        {
          name  = "CLOUDWATCH_METRICS_ENABLED"
          value = "true"
        }
      ]

      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = var.jwt_secret_arn
        },
        {
          name      = "DB_URL"
          valueFrom = "${var.db_credentials_secret_arn}:url::"
        },
        {
          name      = "DB_USERNAME"
          valueFrom = "${var.db_credentials_secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.db_credentials_secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "educloud-backend-task"
    Environment = var.environment
  }
}

# ========================================
# ECS Service
# ========================================
resource "aws_ecs_service" "educloud_backend" {
  name            = "educloud-backend"
  cluster         = aws_ecs_cluster.educloud.id
  task_definition = aws_ecs_task_definition.educloud_backend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.educloud_backend.arn
    container_name   = "educloud-backend"
    container_port   = 8080
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  enable_execute_command = true  # Para debugging con ECS Exec

  depends_on = [aws_lb_listener.http]

  tags = {
    Name        = "educloud-backend-service"
    Environment = var.environment
  }
}

# ========================================
# Auto Scaling
# ========================================

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = var.desired_count
  resource_id        = "service/${aws_ecs_cluster.educloud.name}/${aws_ecs_service.educloud_backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "educloud-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  name               = "educloud-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ========================================
# CloudWatch Alarms
# ========================================

# High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "educloud-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS service CPU utilization is too high"

  dimensions = {
    ClusterName = aws_ecs_cluster.educloud.name
    ServiceName = aws_ecs_service.educloud_backend.name
  }
}

# High Memory Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_high_memory" {
  alarm_name          = "educloud-ecs-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS service memory utilization is too high"

  dimensions = {
    ClusterName = aws_ecs_cluster.educloud.name
    ServiceName = aws_ecs_service.educloud_backend.name
  }
}

# ========================================
# Outputs
# ========================================
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.educloud.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.educloud.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.educloud.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.educloud_backend.name
}

output "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}
