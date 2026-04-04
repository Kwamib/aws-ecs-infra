# ==========================================
# Auto Scaling Policies
# ==========================================

resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.clixx_asg.name
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.clixx_asg.name
  policy_type            = "SimpleScaling"
}

# ==========================================
# CloudWatch Alarms
# ==========================================

resource "aws_cloudwatch_metric_alarm" "clixx_high_cpu_alarm" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Scale up when CPU exceeds 75% for 2 consecutive periods"
  actions_enabled     = true
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.clixx_asg.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_up_policy.arn,
    aws_sns_topic.cloudwatch_alarms_topic.arn
  ]

  ok_actions = [aws_sns_topic.cloudwatch_alarms_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "clixx_low_cpu_alarm" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale down when CPU below 30% for 15 consecutive minutes"
  actions_enabled     = true
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.clixx_asg.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_down_policy.arn,
    aws_sns_topic.cloudwatch_alarms_topic.arn
  ]

  ok_actions = [aws_sns_topic.cloudwatch_alarms_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "clixx_high_memory_alarm" {
  alarm_name          = "${var.project_name}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when memory utilization exceeds 80%"
  actions_enabled     = true
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.clixx_asg.name
  }

  alarm_actions = [aws_sns_topic.cloudwatch_alarms_topic.arn]
  ok_actions    = [aws_sns_topic.cloudwatch_alarms_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "clixx_unhealthy_hosts_alarm" {
  alarm_name          = "${var.project_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alert when there are unhealthy hosts in the target group"
  actions_enabled     = true
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.clixx_nlb_tg_80.arn_suffix
    LoadBalancer = aws_lb.clixx_nlb.arn_suffix
  }

  alarm_actions = [aws_sns_topic.cloudwatch_alarms_topic.arn]
  ok_actions    = [aws_sns_topic.cloudwatch_alarms_topic.arn]
}

# ==========================================
# SNS Topic for Alarm Notifications
# ==========================================

resource "aws_sns_topic" "cloudwatch_alarms_topic" {
  name = "${var.project_name}-cloudwatch-alarms"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alarm_subscription" {
  topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ==========================================
# CloudWatch Dashboard
# ==========================================

resource "aws_cloudwatch_dashboard" "clixx_dashboard" {
  dashboard_name = "${title(var.project_name)}-Monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          view = "timeSeries", stacked = false,
          title = "CPU Utilization (ASG)", region = var.aws_region,
          metrics = [["AWS/AutoScaling", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.clixx_asg.name]],
          period = 300, stat = "Average",
          annotations = {
            horizontal = [
              { label = "Scale Up (75%)", value = 75, color = "#ff0000", fill = "above" },
              { label = "Scale Down (30%)", value = 30, color = "#00ff00", fill = "below" }
            ]
          },
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          view = "timeSeries", title = "Memory Utilization (ASG)", region = var.aws_region,
          metrics = [["CWAgent", "MemoryUtilization", "AutoScalingGroupName", aws_autoscaling_group.clixx_asg.name]],
          period = 300, stat = "Average",
          annotations = { horizontal = [{ label = "High Memory (80%)", value = 80, color = "#ff0000", fill = "above" }] },
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6,
        properties = {
          view = "timeSeries", title = "Healthy Hosts (NLB)", region = var.aws_region,
          metrics = [
            ["AWS/NetworkELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.clixx_nlb_tg_80.arn_suffix, "LoadBalancer", aws_lb.clixx_nlb.arn_suffix],
            [".", ".", "TargetGroup", aws_lb_target_group.clixx_nlb_tg_443.arn_suffix, "LoadBalancer", aws_lb.clixx_nlb.arn_suffix]
          ],
          period = 60, stat = "Average"
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6,
        properties = {
          view = "timeSeries", title = "Unhealthy Hosts (NLB)", region = var.aws_region,
          metrics = [
            ["AWS/NetworkELB", "UnHealthyHostCount", "TargetGroup", aws_lb_target_group.clixx_nlb_tg_80.arn_suffix, "LoadBalancer", aws_lb.clixx_nlb.arn_suffix],
            [".", ".", "TargetGroup", aws_lb_target_group.clixx_nlb_tg_443.arn_suffix, "LoadBalancer", aws_lb.clixx_nlb.arn_suffix]
          ],
          period = 60, stat = "Maximum"
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6,
        properties = {
          view = "timeSeries", title = "New Flow Count (NLB)", region = var.aws_region,
          metrics = [["AWS/NetworkELB", "NewFlowCount", "LoadBalancer", aws_lb.clixx_nlb.arn_suffix]],
          period = 60, stat = "Sum"
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6,
        properties = {
          view = "timeSeries", title = "ASG Instance Count", region = var.aws_region,
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.clixx_asg.name],
            [".", "GroupInServiceInstances", ".", "."],
            [".", "GroupTotalInstances", ".", "."]
          ],
          period = 300, stat = "Average"
        }
      }
    ]
  })
}

# ==========================================
# CloudWatch Log Group for ECS
# ==========================================

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/aws/ecs/${var.project_name}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-logs"
  })
}

# ==========================================
# CloudWatch Agent Config (SSM Parameter)
# ==========================================

resource "aws_ssm_parameter" "cwagent_config" {
  name = "/${var.project_name}/cwagent/config"
  type = "String"
  tier = "Standard"

  value = jsonencode({
    metrics = {
      append_dimensions = {
        InstanceId = "$${!aws:InstanceId}"
      },
      metrics_collected = {
        mem = {
          measurement                 = ["mem_used_percent"]
          metrics_collection_interval = 60
        },
        disk = {
          measurement                 = ["used_percent"]
          metrics_collection_interval = 60
          resources                   = ["*"]
        }
      }
    }
  })

  tags = local.common_tags
}
