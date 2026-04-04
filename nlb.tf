# ==========================================
# Network Load Balancer
# ==========================================

resource "aws_lb" "clixx_nlb" {
  name               = "${var.project_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  enable_cross_zone_load_balancing = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nlb"
  })
}

# TCP Listener (Port 80)
resource "aws_lb_listener" "clixx_nlb_listener_80" {
  load_balancer_arn = aws_lb.clixx_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_nlb_tg_80.arn
  }
}

# TLS Listener (Port 443)
resource "aws_lb_listener" "clixx_nlb_listener_443" {
  load_balancer_arn = aws_lb.clixx_nlb.arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = data.aws_acm_certificate.clixx_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_nlb_tg_443.arn
  }
}

# Target Group — Port 80
resource "aws_lb_target_group" "clixx_nlb_tg_80" {
  name                 = "${var.project_name}-nlb-tg-80"
  port                 = 80
  protocol             = "TCP"
  vpc_id               = aws_vpc.clixx_vpc.id
  target_type          = "ip"
  deregistration_delay = 10

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nlb-tg-80"
  })
}

# Target Group — Port 443 (forwards to container port 80)
resource "aws_lb_target_group" "clixx_nlb_tg_443" {
  name                 = "${var.project_name}-nlb-tg-443"
  port                 = 80
  protocol             = "TCP"
  vpc_id               = aws_vpc.clixx_vpc.id
  target_type          = "ip"
  deregistration_delay = 10

  health_check {
    protocol            = "HTTP"
    port                = "80"
    path                = "/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200-299"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nlb-tg-443"
  })
}
