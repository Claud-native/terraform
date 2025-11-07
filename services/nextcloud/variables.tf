variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "s3_bucket_name" {
  description = "S3 bucket name for Nextcloud storage"
  type        = string
}
