variable "instance_profile_name" {
  description = "Name of an existing IAM instance profile to attach to EC2 instances (use 'labuser' in AWS Academy)."
  type        = string
  default     = "LabInstanceProfile"
}
