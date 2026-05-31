variable "project_name" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from network module"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB"
}

variable "alb_sg_id" {
  type        = string
  description = "Security group ID for the ALB"
}
