# ==========================================
# Auto Scaling Group for ECS EC2 Instances
# ==========================================

resource "aws_autoscaling_group" "clixx_asg" {
  name                = "${var.project_name}-ecs-asg"
  vpc_zone_identifier = [for subnet in aws_subnet.private_subnets : subnet.id]

  health_check_type         = "EC2"
  health_check_grace_period = 600

  min_size         = var.min_capacity
  max_size         = var.max_capacity
  desired_capacity = var.desired_count

  launch_template {
    id      = aws_launch_template.clixx_ecs_lt.id
    version = "$Latest"
  }

  protect_from_scale_in = true

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}
