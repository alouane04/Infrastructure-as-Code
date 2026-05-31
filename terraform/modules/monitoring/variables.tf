variable "project_name" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for infrastructure alerts"
}

variable "alb_arn" {
  type        = string
  description = "ALB ARN from loadbalancer module"
}

variable "target_group_arn" {
  type        = string
  description = "Target group ARN from loadbalancer module"
}
