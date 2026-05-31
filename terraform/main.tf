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

module "compute" {
    source = "./modules/compute"

    project_name              = var.project_name
    aws_region                = local.aws_region
    app_instance_type         = local.app_instance
    app_sg_id                 = module.security.app_sg_id
    private_app_subnet_ids    = module.network.private_app_subnet_ids
    ec2_instance_profile_name = module.secrets.ec2_instance_profile_name
    target_group_arn          = module.loadbalancer.target_group_arn
    min_instances             = var.min_instances
    max_instances             = var.max_instances
    db_password_secret_name   = module.secrets.db_password_secret_name
    session_secret_name       = module.secrets.session_secret_name
    db_host                   = module.database.db_host
    db_port                   = module.database.db_port
    db_username               = module.database.db_username
    db_name                   = module.database.db_name
    redis_url                 = module.cache.redis_url
}

module "loadbalancer" {
    source = "./modules/loadbalancer"
    project_name = var.project_name
    vpc_id = module.network.vpc_id
    public_subnet_ids = module.network.public_subnet_ids
    alb_sg_id = module.security.alb_sg_id   
}

module "monitoring" {
  source           = "./modules/monitoring"
  project_name     = var.project_name
  alert_email      = var.alert_email
  alb_arn          = module.loadbalancer.alb_arn
  target_group_arn = module.loadbalancer.target_group_arn
}
