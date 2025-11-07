# ========================================
# S3 BUCKET para Nextcloud
# ========================================
resource "aws_s3_bucket" "nextcloud" {
  bucket = "nextcloud-storage-${var.account_id}"

  tags = {
    Name        = "nextcloud-storage"
    Environment = "production"
  }
}

# ========================================
# BLOCK PUBLIC ACCESS
# ========================================
resource "aws_s3_bucket_public_access_block" "nextcloud" {
  bucket = aws_s3_bucket.nextcloud.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================================
# BUCKET VERSIONING
# ========================================
resource "aws_s3_bucket_versioning" "nextcloud" {
  bucket = aws_s3_bucket.nextcloud.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ========================================
# SERVER-SIDE ENCRYPTION
# ========================================
resource "aws_s3_bucket_server_side_encryption_configuration" "nextcloud" {
  bucket = aws_s3_bucket.nextcloud.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ========================================
# LIFECYCLE POLICY
# ========================================
resource "aws_s3_bucket_lifecycle_configuration" "nextcloud" {
  bucket = aws_s3_bucket.nextcloud.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ========================================
# VPC ENDPOINT para S3 (acceso privado)
# ========================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = {
    Name = "s3-vpc-endpoint"
  }
}

# ========================================
# BUCKET POLICY - Solo acceso desde VPC
# ========================================
resource "aws_s3_bucket_policy" "nextcloud" {
  bucket = aws_s3_bucket.nextcloud.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowVPCAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.lab_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.nextcloud.arn,
          "${aws_s3_bucket.nextcloud.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.s3.id
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.nextcloud
  ]
}

# ========================================
# OUTPUTS
# ========================================
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.nextcloud.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.nextcloud.arn
}

output "vpc_endpoint_id" {
  description = "ID of the VPC endpoint for S3"
  value       = aws_vpc_endpoint.s3.id
}
