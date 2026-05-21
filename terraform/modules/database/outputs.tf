output "db_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "Full MySQL endpoint including port (host:port)"
}

output "db_host" {
  value       = aws_db_instance.main.address
  description = "MySQL hostname only"
}

output "db_port" {
  value       = aws_db_instance.main.port
  description = "MySQL port"
}

output "db_name" {
  value       = aws_db_instance.main.db_name
  description = "Database name"
}

output "db_username" {
  value       = aws_db_instance.main.username
  description = "Master username"
}
