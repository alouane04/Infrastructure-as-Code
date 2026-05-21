variable "project_name" {
    type = string
}

variable "private_data_subnet_ids" {
    type = list(string)
    description = "List of private data subnet IDs for the DB subnet group"
}

variable "rds_sg_id" {
    type = string
    description = "Security group ID for RDS"
}

variable "db_instance_class" {
    type = string
    description = "RDS instance class (e.g. db.t3.micro)"
}

variable "db_password" {
    type = string
    description = "Master DB password"
    sensitive = true
}

variable "multi_az" {
    type = bool
    description = "Enabl Multi-AZ for high availability"
    default = false
}
