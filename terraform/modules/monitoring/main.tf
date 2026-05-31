resource "aws_sns_topic" "alerts" {
    name = "${var.project_name}-alerts"
    tags = {
        Name = "${var.project_name}-alerts"
    }
}

resource "aws_sns_topic_subscription" "email" {
    topic_arn = aws_sns_topic.alerts.arn
    protocol = "email"
    endpoint = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
    alarm_name          = "${var.project_name}-unhealthy-hosts"
    alarm_description   = "Alert when any app instance becomes unhealthy"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "UnHealthyHostCount"
    namespace           = "AWS/ApplicationELB"
    period              = 60
    statistic           = "Average"
    threshold           = 0
    treat_missing_data  = "breaching"

    dimensions = {
        LoadBalancer = var.alb_arn
        TargetGroup  = var.target_group_arn
    }

    alarm_actions = [aws_sns_topic.alerts.arn]
    ok_actions    = [aws_sns_topic.alerts.arn]

    tags = {
        Name = "${var.project_name}-unhealthy-hosts"
    }
}

resource "aws_cloudwatch_metric_alarm" "high_5xx" {
    alarm_name          = "${var.project_name}-high-5xx"
    alarm_description   = "Alert when app returns too many 5xx errors"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "HTTPCode_Target_5XX_Count"
    namespace           = "AWS/ApplicationELB"
    period              = 60
    statistic           = "Sum"
    threshold           = 10
    treat_missing_data  = "notBreaching"

    dimensions = {
        LoadBalancer = var.alb_arn
    }

    alarm_actions = [aws_sns_topic.alerts.arn]

    tags = {
        Name = "${var.project_name}-high-5xx"
    }
}

resource "aws_cloudwatch_metric_alarm" "high_response_time" {
    alarm_name          = "${var.project_name}-high-response-time"
    alarm_description   = "Alert when app response time exceeds 2 seconds"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 3
    metric_name         = "TargetResponseTime"
    namespace           = "AWS/ApplicationELB"
    period              = 60
    statistic           = "Average"
    threshold           = 2
    treat_missing_data  = "notBreaching"

    dimensions = {
        LoadBalancer = var.alb_arn
    }

    alarm_actions = [aws_sns_topic.alerts.arn]

    tags = {
        Name = "${var.project_name}-high-response-time"
    }
}
