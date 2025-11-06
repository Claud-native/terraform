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
  tags   = { Name = "nextcloud-data" }
}

resource "aws_s3_bucket_ownership_controls" "nextcloud_data" {
  bucket = aws_s3_bucket.nextcloud_data.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_versioning" "nextcloud_data" {
  bucket = aws_s3_bucket.nextcloud_data.id
  versioning_configuration { status = "Enabled" }
}

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
# IAM (mínimo para S3)
# ==========================
resource "aws_iam_policy" "nextcloud_s3_policy" {
  name        = "nextcloud-s3-policy"
  description = "Acceso mínimo al bucket de Nextcloud"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = [aws_s3_bucket.nextcloud_data.arn]
      },
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        Resource = ["${aws_s3_bucket.nextcloud_data.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_to_task_role" {
  count      = var.attach_policies ? 1 : 0
  role       = element(split("/", var.task_role_arn), length(split("/", var.task_role_arn)) - 1)
  policy_arn = aws_iam_policy.nextcloud_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_ecs_execution" {
  count      = var.attach_policies ? 1 : 0
  role       = element(split("/", var.execution_role_arn), length(split("/", var.execution_role_arn)) - 1)
  policy_arn = "arn:aws:iam::891377069738:role/LabRole"
}

# ==========================
# EFS (persistencia)
# ==========================
resource "aws_security_group" "efs" {
  name        = "nextcloud-efs-sg"
  description = "EFS: permite NFS desde el SG privado de ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.private_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "nextcloud-efs-sg" }
}

resource "aws_efs_file_system" "nextcloud" {
  lifecycle_policy { transition_to_ia = "AFTER_30_DAYS" }
  encrypted = true
  tags      = { Name = "nextcloud-efs" }
}

resource "aws_efs_mount_target" "nextcloud" {
  file_system_id  = aws_efs_file_system.nextcloud.id
  subnet_id       = var.private_subnet_id
  security_groups = [aws_security_group.efs.id]
}

# ==========================
# Script de inicialización
# ==========================
locals {
  nc_init_cmd = <<-EOS
set -e
echo "[nc-init] starting"
mkdir -p /var/www/html/config /var/www/html/data

# Escribimos SOLO el drop-in de S3, no tocamos config.php
if [ ! -f /var/www/html/config/s3.config.php ]; then
  echo "[nc-init] writing s3.config.php"
  cat > /var/www/html/config/s3.config.php <<'PHP'
<?php
$CONFIG = array (
  'objectstore' => array(
    'class' => '\\OC\\Files\\ObjectStore\\S3',
    'arguments' => array(
      'bucket' => getenv('OBJECTSTORE_S3_BUCKET'),
      'region' => getenv('OBJECTSTORE_S3_REGION'),
      'autocreate' => true,
      'use_path_style' => true
    ),
  ),
);
PHP
  echo "[nc-init] CREATED s3.config.php"
else
  echo "[nc-init] s3.config.php already present"
fi

chown -R 33:33 /var/www/html/config /var/www/html/data
chmod -R 750 /var/www/html/config
chmod -R 770 /var/www/html/data
echo "[nc-init] PERMS OK"
exit 0
  EOS
}


# ==========================
# ECS Task Definition
# ==========================
resource "aws_ecs_task_definition" "nextcloud" {
  family                   = "nextcloud-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "2048"
  memory                   = "8192"

  task_role_arn      = var.task_role_arn
  execution_role_arn = var.execution_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture         = "X86_64"
  }

  volume {
    name = "ncdata"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.nextcloud.id
      transit_encryption = "ENABLED"
      root_directory     = "/"
    }
  }

  container_definitions = jsonencode([
    # --- INIT SIDE ---
    {
      name       = "nc-init",
      image      = "alpine:3.20",
      essential  = false,
      command    = ["sh", "-c", "printf %s \"$NC_INIT\" | tr -d '\\r' | sh"],
      environment = [
        { name = "NC_INIT",               value = replace(local.nc_init_cmd, "\r", "") },
        { name = "OBJECTSTORE_S3_BUCKET", value = aws_s3_bucket.nextcloud_data.bucket },
        { name = "OBJECTSTORE_S3_REGION", value = var.region }
      ],
      mountPoints = [
        { sourceVolume = "ncdata", containerPath = "/var/www/html" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_nextcloud.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "init"
        }
      }
    },

# --- MariaDB ---
{
  name       = "db",
  image      = var.mariadb_image,
  essential  = true,
  hostname   = "db",                         # <--- añade esto
  portMappings = [{ containerPort = 3306 }],
  environment = [
    { name = "MARIADB_ROOT_PASSWORD", value = var.db_root_password },
    { name = "MARIADB_DATABASE",      value = var.db_name },
    { name = "MARIADB_USER",          value = var.db_user },
    { name = "MARIADB_PASSWORD",      value = var.db_password },
    { name = "FORCE_ROLLOUT",         value = "ts-${timestamp()}" }
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
    retries     = 10,
    startPeriod = 299
  }
},

# --- Nextcloud ---
{
  name       = "nextcloud",
  image      = var.nextcloud_image,
  essential  = true,
  dependsOn  = [
    { containerName = "db",      condition = "HEALTHY" },
    { containerName = "nc-init", condition = "SUCCESS" }
  ],
  portMappings = [{ containerPort = 80 }],
  environment = [
    { name = "MYSQL_HOST",               value = "db" },        # <--- antes 127.0.0.1
    { name = "MYSQL_PORT",               value = "3306" },      # <--- opcional
    { name = "MYSQL_DATABASE",           value = var.db_name },
    { name = "MYSQL_USER",               value = var.db_user },
    { name = "MYSQL_PASSWORD",           value = var.db_password },
    { name = "NEXTCLOUD_ADMIN_USER",     value = var.nextcloud_admin_user },
    { name = "NEXTCLOUD_ADMIN_PASSWORD", value = var.nextcloud_admin_password },
    { name = "OBJECTSTORE_S3_BUCKET",    value = aws_s3_bucket.nextcloud_data.bucket },
    { name = "OBJECTSTORE_S3_REGION",    value = var.region }
  ],
  mountPoints = [
    { sourceVolume = "ncdata", containerPath = "/var/www/html" }
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
    command     = ["CMD-SHELL", "curl -fsS http://localhost/ || exit 1"],
    interval    = 30,
    timeout     = 5,
    retries     = 5,
    startPeriod = 299
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
  platform_version  = "LATEST"

  force_new_deployment               = true
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [var.private_sg_id]
    assign_public_ip = false
  }
}
