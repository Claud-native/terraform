variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "route_table_ids" {
  description = "List of route table IDs for VPC endpoint"
  type        = list(string)
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "lab_role_arn" {
  description = "ARN of the LabRole"
  type        = string
}
