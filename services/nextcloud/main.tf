# ==========================
# CloudWatch Log Group
# ==========================
resource "aws_cloudwatch_log_group" "ecs_nextcloud" {
  name              = "/ecs/nextcloud"
  retention_in_days = 14
}

# ==========================
# ECS Cluster
# ==========================
resource "aws_ecs_cluster" "nextcloud" {
  name = "nextcloud-cluster"
}

# ==========================
# S3 Bucket para Nextcloud
# ==========================
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "nextcloud_data" {
  bucket = "nextcloud-data-${random_id.bucket_id.hex}"
}

resource "aws_s3_bucket_ownership_controls" "nextcloud_data" {
  bucket = aws_s3_bucket.nextcloud_data.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_versioning" "nextcloud_data" {
  bucket = aws_s3_bucket.nextcloud_data.id
  versioning_configuration { status = "Enabled" }
}

# Endurecimiento (recomendado)
resource "aws_s3_bucket_public_access_block" "nextcloud_data" {
  bucket                  = aws_s3_bucket.nextcloud_data.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "nextcloud_data" {
  bucket = aws_s3_bucket.nextcloud_data.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# ==========================
# (Opcional si NO usas LabRole) Policy para acceso a S3
# ==========================
resource "aws_iam_policy" "nextcloud_s3_policy" {
  name        = "nextcloud-s3-policy"
  description = "Permite acceso al bucket de Nextcloud"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject","s3:GetObject","s3:DeleteObject","s3:ListBucket"],
        Resource = [
          aws_s3_bucket.nextcloud_data.arn,
          "${aws_s3_bucket.nextcloud_data.arn}/*"
        ]
      }
    ]
  })
}

# (Opcional) Adjuntar policy S3 al task role si no usas LabRole admin
resource "aws_iam_role_policy_attachment" "attach_s3_to_task_role" {
  count      = var.attach_policies ? 1 : 0
  role       = element(split("/", var.task_role_arn), length(split("/", var.task_role_arn)) - 1)
  policy_arn = aws_iam_policy.nextcloud_s3_policy.arn
}

# (Opcional) Permisos de ejecución ECS (logs/ECR). Con LabRole suele sobrar.
resource "aws_iam_role_policy_attachment" "attach_ecs_execution" {
  count      = var.attach_policies ? 1 : 0
  role       = element(split("/", var.execution_role_arn), length(split("/", var.execution_role_arn)) - 1)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==========================
# ECS Task Definition
# ==========================
resource "aws_ecs_task_definition" "nextcloud" {
  family                   = "nextcloud-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  # Fargate válido (ajusta si quieres sobredimensionar)
  cpu    = "2048"   # 2 vCPU
  memory = "4096"   # 4 GiB

  task_role_arn      = var.task_role_arn
  execution_role_arn = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name       = "db",
      image      = var.mariadb_image,
      essential  = true,
      portMappings = [{ containerPort = 3306 }],
      environment = [
        { name = "MARIADB_ROOT_PASSWORD", value = var.db_root_password },
        { name = "MARIADB_DATABASE",      value = var.db_name },
        { name = "MARIADB_USER",          value = var.db_user },
        { name = "MARIADB_PASSWORD",      value = var.db_password }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_nextcloud.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "db"
        }
      },
      healthCheck = {
        command     = ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -u$${MARIADB_USER} -p$${MARIADB_PASSWORD} || exit 1"],
        interval    = 30,
        timeout     = 5,
        retries     = 5,
        startPeriod = 60
      }
    },
    {
      name       = "nextcloud",
      image      = var.nextcloud_image,
      essential  = true,
      dependsOn  = [{ containerName = "db", condition = "HEALTHY" }],
      portMappings = [{ containerPort = 80 }],
      environment = [
        { name = "MYSQL_HOST",               value = "127.0.0.1" },
        { name = "MYSQL_DATABASE",           value = var.db_name },
        { name = "MYSQL_USER",               value = var.db_user },
        { name = "MYSQL_PASSWORD",           value = var.db_password },
        { name = "NEXTCLOUD_ADMIN_USER",     value = var.nextcloud_admin_user },
        { name = "NEXTCLOUD_ADMIN_PASSWORD", value = var.nextcloud_admin_password },
        { name = "OBJECTSTORE_S3_BUCKET",    value = aws_s3_bucket.nextcloud_data.bucket },
        { name = "OBJECTSTORE_S3_REGION",    value = var.region }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_nextcloud.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "nextcloud"
        }
      },
      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost/status.php || exit 1"],
        interval    = 30,
        timeout     = 5,
        retries     = 5,
        startPeriod = 60
      }
    }
  ])
}

# ==========================
# ECS Service
# ==========================
resource "aws_ecs_service" "nextcloud" {
  name            = "nextcloud-service"
  cluster         = aws_ecs_cluster.nextcloud.id
  task_definition = aws_ecs_task_definition.nextcloud.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [var.private_sg_id]
    assign_public_ip = false
  }
}

# ==========================
# Outputs
# ==========================
output "cluster_arn"  { value = aws_ecs_cluster.nextcloud.arn }
output "service_name" { value = aws_ecs_service.nextcloud.name }
output "bucket_name"  { value = aws_s3_bucket.nextcloud_data.bucket }
