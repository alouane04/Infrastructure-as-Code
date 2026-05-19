variable "region" {
    type = string
    description = "Human-readable region name (Paris, Ireland, Virginia)"
}

variable "app_instance_size" {
    type = string
    description = "App server size (small, medium, large)"
    default = "small"
}

variable "db_instance_size" {
    type = string
    description = "Database size (small, medium, large)"
    default = "small"
}

variable "min_instances" {
    type = number
    description = "Minimum number of app servers"
    default = 2
}

variable "max_instances" {
    type = number
    description = "Maximum number of app servers"
    default = 4
}

variable "alert_email" {
    type = string
    description = "Email to recive on Infrastructure Alert"
}

variable "project_name" {
    type = string
    description = "Prefix for all resource names"
    default = "iac1"
}
