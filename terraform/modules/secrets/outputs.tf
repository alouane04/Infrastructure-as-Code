output "db_password_arn" {
    value = aws_secretsmanager_secret.db_password.arn
}

output "session_secret_arn" {
    value = aws_secretsmanager_secret.session_secret.arn
}

output "ec2_instance_profile_name" {
    value = aws_iam_instance_profile.ec2_profile.name
}

output "db_password_secret_name" {
    value = aws_secretsmanager_secret.db_password.name
}

output "session_secret_name" {
    value = aws_secretsmanager_secret.session_secret.name
}
