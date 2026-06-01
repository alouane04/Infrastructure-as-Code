////////////  The DB Password Secret  ////////////

resource "aws_secretsmanager_secret" "db_password" {
    name = "${var.project_name}/db_password"
    description = "MySQL database password"
    recovery_window_in_days = 0
    tags = {
        Name = "${var.project_name}-db-password"
    }
}

resource "aws_secretsmanager_secret_version" "db_password" {
    secret_id = aws_secretsmanager_secret.db_password.id
    secret_string = var.db_password
}

////////////  The Session Secret  ////////////

resource "aws_secretsmanager_secret" "session_secret" {
    name                    = "${var.project_name}/session_secret"
    description             = "Express session secret shared across all app instances"
    recovery_window_in_days = 0

    tags = {
        Name = "${var.project_name}-session-secret"
    }
}

resource "aws_secretsmanager_secret_version" "session_secret" {
    secret_id     = aws_secretsmanager_secret.session_secret.id
    secret_string = var.session_secret
}

//////////  IAM Role  //////////////

resource "aws_iam_role" "ec2_role" {
    name = "${var.project_name}-ec2-role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = {
            Service = "ec2.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }
        ]
    })
    tags = {
        Name = "${var.project_name}-ec2-role"
    }
}

//////////  IAM Policy  //////////////

resource "aws_iam_policy" "secrets_read" {
    name = "${var.project_name}-secrets-read"
    description = "Allow EC2 to read secrets from Secrets Manager"
    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Action = [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ]
            Resource = [
                aws_secretsmanager_secret.db_password.arn,
                aws_secretsmanager_secret.session_secret.arn
            ]
        }
    ]
  })
    
}

//////////  Attach Policy to Role  //////////////

resource "aws_iam_role_policy_attachment" "secrets_read" {
    role       = aws_iam_role.ec2_role.name
    policy_arn = aws_iam_policy.secrets_read.arn
}

//////////  Instance Profile  //////////////

resource "aws_iam_instance_profile" "ec2_profile" {
    name = "${var.project_name}-ec2-profile"
    role = aws_iam_role.ec2_role.name
    tags = {
        Name = "${var.project_name}-ec2-profile"
    }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance → wears → Instance Profile → contains → IAM Role
#  → attached to → IAM Policy → allows access to → Secrets Manager Secrets