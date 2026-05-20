resource "aws_security_group" "alb" {
    name = "${var.project_name}-sg-alb"
    description = "Allow HTTP from internet to load balancer"
    vpc_id = var.vpc_id

    ingress {
        description = "HTTP from internet"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "Allow all outbound"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-sg-alb"
    }
}

resource "aws_security_group" "app" {
    name        = "${var.project_name}-sg-app"
    description = "Allow traffic from ALB to app servers"
    vpc_id      = var.vpc_id

    ingress {
        description     = "App port from ALB only"
        from_port       = 3000
        to_port         = 3000
        protocol        = "tcp"
        security_groups = [aws_security_group.alb.id]
    }

    egress {
        description = "Allow all outbound"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-sg-app"
    }
}

resource "aws_security_group" "rds" {
    name        = "${var.project_name}-sg-rds"
    description = "Allow MySQL from app servers only"
    vpc_id      = var.vpc_id

    ingress {
        description     = "MySQL from app servers only"
        from_port       = 3306
        to_port         = 3306
        protocol        = "tcp"
        security_groups = [aws_security_group.app.id]
    }

    egress {
        description = "Allow all outbound"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-sg-rds"
    }
}

resource "aws_security_group" "redis" {
    name        = "${var.project_name}-sg-redis"
    description = "Allow Redis from app servers only"
    vpc_id      = var.vpc_id

    ingress {
        description     = "Redis from app servers only"
        from_port       = 6379
        to_port         = 6379
        protocol        = "tcp"
        security_groups = [aws_security_group.app.id]
    }

    egress {
        description = "Allow all outbound"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.project_name}-sg-redis"
    }
}
