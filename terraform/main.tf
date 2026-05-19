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
