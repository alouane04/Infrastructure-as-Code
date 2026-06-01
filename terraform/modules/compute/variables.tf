variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "app_instance_type" {
  type = string
}

variable "app_sg_id" {
  type        = string
  description = "Security group ID for app servers"
}

variable "private_app_subnet_ids" {
  type        = list(string)
  description = "Private app subnet IDs for the ASG"
}

variable "ec2_instance_profile_name" {
  type        = string
  description = "IAM instance profile name from secrets module"
}

variable "target_group_arn" {
  type        = string
  description = "ALB target group ARN — from loadbalancer module"
}

variable "min_instances" {
  type    = number
  default = 2
}

variable "max_instances" {
  type    = number
  default = 4
}

variable "db_password_secret_name" {
  type = string
}

variable "session_secret_name" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_username" {
  type = string
}

variable "db_name" {
  type = string
}

# variable "redis_url" {
#   type = string
# }

variable "redis_host" {
  type = string
}

variable "redis_port" {
  type = string
}
