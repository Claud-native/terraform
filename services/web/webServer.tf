# ========================================
# ECS CLUSTER
# ========================================
resource "aws_ecs_cluster" "web" {
  name = "web-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "web-ecs-cluster"
  }
}

# ========================================
# CLOUDWATCH LOG GROUP para logs de contenedores
# ========================================
resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/web-service"
  retention_in_days = 7

  tags = {
    Name = "web-ecs-logs"
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
resource "aws_ecs_task_definition" "web" {
  family                   = "web-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # 0.25 vCPU
  memory                   = "512"  # 512 MB
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "web-container"
      image     = "nginxdemos/hello:latest"  # Imagen de nginx con p�gina de prueba
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.web.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "web"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "web-task-definition"
  }
}

# ========================================
# SECURITY GROUP para ECS Tasks
# ========================================
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "Security group for ECS tasks - allows traffic from ALB"
  vpc_id      = var.vpc_id

  # Permitir tr�fico HTTP desde el ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.security_group_id]
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
    Name = "ecs-tasks-security-group"
  }
}

# ========================================
# ECS SERVICE con 2 instancias
# ========================================
resource "aws_ecs_service" "web" {
  name            = "web-service"
  cluster         = aws_ecs_cluster.web.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 2  # 2 instancias web
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true  # Necesario para Fargate en subnet p�blica
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web-container"
    container_port   = 80
  }

  # Esperar a que el ALB est� listo antes de crear el servicio
  depends_on = [aws_lb_listener.http]

  # Deployment configuration
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # Health check grace period
  health_check_grace_period_seconds = 60

  tags = {
    Name = "web-ecs-service"
  }
}

# ========================================
# OUTPUTS
# ========================================
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.web.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.web.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.web.arn
}
