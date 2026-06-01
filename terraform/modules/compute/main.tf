data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["099720109477"] // Canonical's AWS account ID

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_launch_template" "app" {
    name_prefix   = "${var.project_name}-lt-"
    image_id = data.aws_ami.ubuntu.id
    instance_type = var.app_instance_type

    network_interfaces {
        associate_public_ip_address = false
        security_groups = [var.app_sg_id]
    }

    iam_instance_profile {
        name = var.ec2_instance_profile_name
    }

    user_data = base64encode(templatefile("${path.module}/user_data.sh", {
        aws_region = var.aws_region
        db_password_secret_name = var.db_password_secret_name
        session_secret_name = var.session_secret_name
        db_host = var.db_host
        db_port = var.db_port
        db_username = var.db_username
        db_name = var.db_name
        # redis_url = var.redis_url
        redis_host  = var.redis_host
        redis_port  = var.redis_port
    }))

    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "${var.project_name}-app"
        }
    }

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "app" {
    name = "${var.project_name}-asg"
    min_size = var.min_instances
    max_size = var.max_instances
    desired_capacity = var.min_instances
    vpc_zone_identifier = var.private_app_subnet_ids
    # this is where the asg connect with lb
    target_group_arns = [var.target_group_arn]
    # instead the asg check the instance  (phisicaly) it ask lb to check to return 200
    health_check_type = "ELB"
    # cool time before start checking instance health
    health_check_grace_period = 120

    launch_template {
        id = aws_launch_template.app.id
        version = "$Latest"
    }

    instance_refresh {
        strategy = "Rolling"
        preferences {
            min_healthy_percentage = 50
        }
    }

    tag {
        key = "Name"
        value = "${var.project_name}-app"
        propagate_at_launch = true
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_policy" "scale_up" {
    name = "${var.project_name}-scale-up"
    autoscaling_group_name = aws_autoscaling_group.app.name
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = 1
    cooldown = 120
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
    alarm_name = "${var.project_name}-cpu-high"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 2
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = 60
    statistic = "Average"
    threshold = 70
    alarm_description = "Scale up when CPU > 70% for 2min"
    alarm_actions = [aws_autoscaling_policy.scale_up.arn]
    dimensions = {
      AutoscalingGroupName = aws_autoscaling_group.app.name
    }
}

resource "aws_autoscaling_policy" "scale_down" {
    name = "${var.project_name}-scale-down"
    autoscaling_group_name = aws_autoscaling_group.app.name
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = -1
    cooldown = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
    alarm_name = "${var.project_name}-cpu-low"
    comparison_operator = "LessThanThreshold"
    evaluation_periods = 5
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = 60
    statistic = "Average"
    threshold = 30
    alarm_description = "Scale down when CPU > 30% for 5min"
    alarm_actions = [aws_autoscaling_policy.scale_down.arn]
    dimensions = {
      AutoscalingGroupName = aws_autoscaling_group.app.name
    }
}
