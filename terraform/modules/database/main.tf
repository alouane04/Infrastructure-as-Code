////////////  DB Subnet Group  ////////////////

resource "aws_db_subnet_group" "main" {
    name = "${var.project_name}-db-subnet-group"
    description = "Subnet group for RDS MySQL"
    subnet_ids = var.private_data_subnet_ids

    tags = {
        Name = "${var.project_name}-db-subnet-group"
    }
}

//////////  DB Parameter Group  ////////////

resource "aws_db_parameter_group" "main" {
    name = "${var.project_name}-db-params"
    family = "mysql8.0"
    description = "Parameter group for MySQL 8.0"

    parameter {
        name = "character_set_server"
        value = "utf8mb4"
    }
    parameter {
        name = "collation_server"
        value = "utf8mb4_unicode_ci"
    }

    tags = {
        Name = "${var.project_name}-db-params"
    }
}

///////////  DB instance  //////////////

resource "aws_db_instance" "main" {
    identifier = "${var.project_name}-mysql"

    # Engine
    engine = "mysql"
    engine_version = "8.0"
    instance_class = var.db_instance_class

    # Storage
    allocated_storage = 20
    max_allocated_storage = 100
    storage_type = "gp2"
    storage_encrypted = true

    # Database
    db_name = "todo_app"
    username = "admin"
    password = var.db_password
    
    # Network
    db_subnet_group_name = aws_db_subnet_group.main.name
    vpc_security_group_ids = [var.rds_sg_id]
    publicly_accessible = false

    # Config
    parameter_group_name = aws_db_parameter_group.main.name
    multi_az = var.multi_az
    skip_final_snapshot = true

    # Backups
    backup_retention_period = 1
    backup_window = "03:00-04:00"
    maintenance_window = "Mon:04:00-Mon:05:00"

    tags = {
        Name = "${var.project_name}-mysql"
    }
}
