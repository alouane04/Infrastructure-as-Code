output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "SNS topic ARN for alerts"
}
