variable "project_name" {
  type = string
}

variable "private_data_subnet_ids" {
  type        = list(string)
  description = "Private data subnet IDs for Redis subnet group"
}

variable "redis_sg_id" {
  type        = string
  description = "Security group ID for Redis"
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache node type (e.g. cache.t3.micro)"
  default     = "cache.t3.micro"
}
