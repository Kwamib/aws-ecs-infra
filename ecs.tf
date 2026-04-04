# ==========================================
# ECS Cluster
# ==========================================

resource "aws_ecs_cluster" "clixx_cluster" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-cluster"
  })
}

# ==========================================
# ECS Capacity Provider (linked to ASG)
# ==========================================

resource "aws_ecs_capacity_provider" "clixx_capacity_provider" {
  name = "${var.project_name}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.clixx_asg.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-capacity-provider"
  })
}

resource "aws_ecs_cluster_capacity_providers" "clixx_cluster_cp" {
  cluster_name       = aws_ecs_cluster.clixx_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.clixx_capacity_provider.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.clixx_capacity_provider.name
  }
}

# ==========================================
# ECS Task Definition
# ==========================================

resource "aws_ecs_task_definition" "clixx_task" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "${var.project_name}-ecs-app"
    image     = var.container_image
    cpu       = var.task_cpu
    memory    = var.task_memory
    essential = true
    command   = ["apache2-foreground"]

    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "WORDPRESS_CONFIG_EXTRA"
        value = "define('WP_HOME', '${local.app_url}'); define('WP_SITEURL', '${local.app_url}'); $_SERVER['HTTPS'] = 'on'; $_SERVER['SERVER_PORT'] = 443;"
      }
    ]

    secrets = [
      { name = "DB_HOST", valueFrom = "/${var.project_name}/db_host" },
      { name = "DB_NAME", valueFrom = "/${var.project_name}/wp_db_name" },
      { name = "DB_USER", valueFrom = "/${var.project_name}/wp_db_user" },
      { name = "DB_PASSWORD", valueFrom = "/${var.project_name}/clixx_db_password" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/aws/ecs/${var.project_name}"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
        awslogs-create-group  = "true"
      }
    }
  }])
}

# ==========================================
# ECS Service
# ==========================================

resource "aws_ecs_service" "clixx_service" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.clixx_cluster.id
  task_definition = aws_ecs_task_definition.clixx_task.arn
  desired_count   = var.desired_count
  force_delete    = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.clixx_capacity_provider.name
    weight            = 1
  }

  network_configuration {
    subnets          = [for subnet in aws_subnet.private_subnets : subnet.id]
    security_groups  = [aws_security_group.clixx_task_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.clixx_nlb_tg_80.arn
    container_name   = "${var.project_name}-ecs-app"
    container_port   = var.container_port
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.clixx_nlb_tg_443.arn
    container_name   = "${var.project_name}-ecs-app"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds  = 300
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200
  force_new_deployment               = var.force_deploy
  enable_execute_command             = true

  depends_on = [
    aws_ecs_cluster.clixx_cluster,
    aws_ecs_capacity_provider.clixx_capacity_provider,
    aws_ssm_parameter.db_endpoint,
    data.aws_ssm_parameter.wp_db_name,
    data.aws_ssm_parameter.wp_db_user,
    data.aws_ssm_parameter.db_password
  ]

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-service"
  })
}

# ==========================================
# Launch Template for ECS EC2 Instances
# ==========================================

resource "aws_launch_template" "clixx_ecs_lt" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.asg_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(file("${path.module}/userdata.sh"))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-ecs-instance"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-launch-template"
  })
}
