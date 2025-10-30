# ========================================
# ECS CLUSTER
# ========================================
resource "aws_ecs_cluster" "api" {
  name = "api-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "api-ecs-cluster"
  }
}

# ========================================
# CLOUDWATCH LOG GROUP para logs de contenedores
# ========================================
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/api-service"
  retention_in_days = 7

  tags = {
    Name = "api-ecs-logs"
  }
}

# ========================================
# IAM ROLE para ECS Task Execution
# ========================================
# En AWS Academy/Labs, usa el rol existente LabRole
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ========================================
# ECS TASK DEFINITION
# ========================================
resource "aws_ecs_task_definition" "api" {
  family                   = "api-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # 0.25 vCPU
  memory                   = "512"  # 512 MB
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "api-container"
      image     = "975049956608.dkr.ecr.us-east-1.amazonaws.com/spring/api:latest"
      essential = true

      environment = [
        {
          name  = "SPRING_DATASOURCE_URL"
          value = "jdbc:mysql://${var.db_endpoint}:${var.db_port}/${var.db_name}"
        },
        {
          name  = "SPRING_DATASOURCE_USERNAME"
          value = var.db_username
        },
        {
          name  = "SPRING_DATASOURCE_DRIVER_CLASS_NAME"
          value = "com.mysql.cj.jdbc.Driver"
        },
        {
          name  = "SPRING_JPA_HIBERNATE_DDL_AUTO"
          value = "update"
        },
        {
          name  = "SPRING_JPA_SHOW_SQL"
          value = "false"
        },
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
      ]

      secrets = [
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "${var.db_secret_arn}:password::"
        }
      ]

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "api"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "api-task-definition"
  }
}

# ========================================
# SECURITY GROUP para ECS Tasks
# ========================================
resource "aws_security_group" "api_ecs_tasks" {
  name        = "api-ecs-tasks-sg"
  description = "Security group for API ECS tasks - allows traffic from private network"
  vpc_id      = var.vpc_id

  # Permitir tr�fico en puerto 8080 desde el security group privado
  ingress {
    description     = "Spring Boot API from private network"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.security_group_id]
  }

  # Permitir tr�fico desde el NLB (mismo security group)
  ingress {
    description = "Allow from NLB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }

  # Salida: permitir todo el tr�fico saliente
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "api-ecs-tasks-security-group"
  }
}

# ========================================
# ECS SERVICE con 2 instancias
# ========================================
resource "aws_ecs_service" "api" {
  name            = "api-service"
  cluster         = aws_ecs_cluster.api.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2  # 2 instancias API
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.api_ecs_tasks.id]
    assign_public_ip = false  # Red privada, no necesita IP p�blica
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api-container"
    container_port   = 8080
  }

  # Esperar a que el NLB est� listo antes de crear el servicio
  depends_on = [aws_lb_listener.api]

  # Deployment configuration
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # Health check grace period
  health_check_grace_period_seconds = 60

  # Habilitar ECS Exec para acceso a contenedores
  enable_execute_command = true

  tags = {
    Name = "api-ecs-service"
  }
}

# ========================================
# OUTPUTS
# ========================================
output "ecs_cluster_name" {
  description = "Name of the API ECS cluster"
  value       = aws_ecs_cluster.api.name
}

output "ecs_service_name" {
  description = "Name of the API ECS service"
  value       = aws_ecs_service.api.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the API ECS task definition"
  value       = aws_ecs_task_definition.api.arn
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer (internal)"
  value       = aws_lb.api.dns_name
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.api.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.api.arn
}

output "api_security_group_id" {
  description = "Security group ID of API ECS tasks"
  value       = aws_security_group.api_ecs_tasks.id
}