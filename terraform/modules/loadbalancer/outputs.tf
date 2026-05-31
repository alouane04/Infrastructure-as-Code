output "target_group_arn" {
  value       = aws_lb_target_group.app.arn
  description = "Target group ARN — consumed by compute module for ASG"
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "Public DNS name of the load balancer"
}

output "alb_arn" {
  value       = aws_lb.main.arn
  description = "ALB ARN — consumed by monitoring module"
}
