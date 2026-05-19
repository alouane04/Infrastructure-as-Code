output "vpc_id" {
    value = aws_vpc.main.id
}

output "public_subnet_ids" {
    value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_app_subnet_ids" {
    value = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
}

output "private_data_subnet_ids" {
    value = [aws_subnet.private_data_a.id, aws_subnet.private_data_b.id]
}
