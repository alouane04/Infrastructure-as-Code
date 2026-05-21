output "redis_host" {
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
  description = "Redis hostname"
}

output "redis_port" {
  value       = aws_elasticache_cluster.main.port
  description = "Redis port"
}

output "redis_url" {
  value       = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:${aws_elasticache_cluster.main.port}"
  description = "Full Redis URL for the app"
}
