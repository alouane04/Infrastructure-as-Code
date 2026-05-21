terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = local.aws_region
}

module "network" {
    source = "./modules/network"
    project_name = var.project_name
    aws_region = local.aws_region
}

module "security" {
    source = "./modules/security"
    project_name = var.project_name
    vpc_id = module.network.vpc_id
}

module "secrets" {
    source = "./modules/secrets"
    project_name = var.project_name
    db_password = var.db_password
    session_secret = var.session_secret
}

module "database" {
    source = "./modules/database"
    project_name = var.project_name
    private_data_subnet_ids = module.network.private_data_subnet_ids
    rds_sg_id = module.security.rds_sg_id
    db_instance_class = local.db_instance
    db_password = var.db_password
    multi_az = var.multi_az
}

module "cache" {
    source = "./modules/cache"
    project_name = var.project_name
    private_data_subnet_ids = module.network.private_data_subnet_ids
    redis_sg_id = module.security.redis_sg_id
    redis_node_type = local.redis_node
}
