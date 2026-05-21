////////////  Cache Subnet Group  /////////////

resource "aws_elasticache_subnet_group" "main" {
    name = "${var.project_name}-redis-subnet-group"
    description = "Subnet group for ElastiCache Redis"
    subnet_ids = var.private_data_subnet_ids

    tags = {
      Name = "${var.project_name}-redis-subnet-group"
    }
}

////////////  Cache Parameter Group  /////////////

resource "aws_elasticache_parameter_group" "main" {
    name = "${var.project_name}-redis-params"
    family = "redis7"
    description = "Parameter group for Redis 7"

    parameter {
        name = "maxmemory-policy"
        value = "allkeys-lru"
    }
    tags = {
        Name = "${var.project_name}-redis-params"
    }
}

///////////////  The ElastiCache Cluster  /////////////

resource "aws_elasticache_cluster" "main" {
    cluster_id = "${var.project_name}-redis"
    engine = "redis"
    engine_version = "7.0"
    node_type = var.redis_node_type
    num_cache_nodes = 1
    port = 6379

    subnet_group_name = aws_elasticache_subnet_group.main.name
    security_group_ids = [var.redis_sg_id]
    parameter_group_name = aws_elasticache_parameter_group.main.name

    # Maintenance
    maintenance_window = "tue:05:00-tue:06:00"
    snapshot_retention_limit = 0

    tags = {
        Name = "${var.project_name}-redis"
    }
}
