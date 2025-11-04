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

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "nextcloud_data" {
  bucket = aws_s3_bucket.nextcloud_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ==========================
# Policy para acceso a S3
# ==========================
resource "aws_iam_policy" "nextcloud_s3_policy" {
  name        = "nextcloud-s3-policy"
  description = "Permite acceso al bucket de Nextcloud"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.nextcloud_data.arn,
          "${aws_s3_bucket.nextcloud_data.arn}/*"
        ]
      }
    ]
  })
}

# ==========================
# ECS Task Definition
# ==========================
resource "aws_ecs_task_definition" "nextcloud" {
  family                   = "nextcloud-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "4 vCPU"
  memory                   = "10 GB"

  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.execution_role_arn 


  container_definitions = jsonencode([
    {
      name  = "db"
      image = var.mariadb_image
      essential = true
      environment = [
        { name = "MYSQL_ROOT_PASSWORD", value = var.db_root_password },
        { name = "MYSQL_DATABASE", value = var.db_name },
        { name = "MYSQL_USER", value = var.db_user },
        { name = "MYSQL_PASSWORD", value = var.db_password }
      ]
      portMappings = [{ containerPort = 3306, hostPort = 3306 }]
    },
    {
      name  = "nextcloud"
      image = var.nextcloud_image
      essential = true
      dependsOn = [{ containerName = "db", condition = "START" }]
      portMappings = [{ containerPort = 80, hostPort = 80 }]
      environment = [
        { name = "MYSQL_HOST", value = "db" },
        { name = "MYSQL_DATABASE", value = var.db_name },
        { name = "MYSQL_USER", value = var.db_user },
        { name = "MYSQL_PASSWORD", value = var.db_password },
        { name = "NEXTCLOUD_ADMIN_USER", value = var.nextcloud_admin_user },
        { name = "NEXTCLOUD_ADMIN_PASSWORD", value = var.nextcloud_admin_password },
        { name = "OBJECTSTORE_S3_BUCKET", value = aws_s3_bucket.nextcloud_data.bucket },
        { name = "OBJECTSTORE_S3_REGION", value = var.region }
      ]
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
    subnets         = [var.private_subnet_id]
    security_groups = [var.private_sg_id]
    assign_public_ip = false
  }
}
