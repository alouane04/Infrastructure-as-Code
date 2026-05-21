variable "project_name" {
    type        = string
    description = "Used to prefix all resource names"
}

variable "db_password" {
    type        = string
    description = "MySQL database password"
    sensitive   = true
}

variable "session_secret" {
    type        = string
    description = "Express session secret"
    sensitive   = true
}