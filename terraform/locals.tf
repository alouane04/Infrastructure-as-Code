locals {
  region_map = {
    "Paris"    = "eu-west-3"
    "Ireland"  = "eu-west-1"
    "Virginia" = "us-east-1"
  }

  app_size_map = {
    "small"  = "t3.micro"
    "medium" = "t3.small"
    "large"  = "t3.medium"
  }

  db_size_map = {
    "small"  = "db.t3.micro"
    "medium" = "db.t3.small"
    "large"  = "db.t3.medium"
  }

  redis_size_map = {
    "small"  = "cache.t3.micro"
    "medium" = "cache.t3.small"
    "large"  = "cache.t3.medium"
  }

  aws_region    = local.region_map[var.region]
  app_instance  = local.app_size_map[var.app_instance_size]
  db_instance   = local.db_size_map[var.db_instance_size]
  redis_node = local.redis_size_map[var.redis_instance_size]
}