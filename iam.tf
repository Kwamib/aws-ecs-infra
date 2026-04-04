# ==========================================
# ECS Instance Role
# ==========================================

resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-instance-role"
  })
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-instance-profile"
  })
}

# Managed policy attachments for instance role
resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_ecr" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_ssm" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_cloudwatch_agent" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for ECS instance operations
resource "aws_iam_policy" "ecs_instance_combined_policy" {
  name = "${var.project_name}-ecs-instance-combined"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ecs:ListTasks", "ecs:DescribeTasks", "ecs:DescribeContainerInstances",
        "ecs:DescribeServices", "ecs:ListServices", "ecs:ListContainerInstances",
        "ecs:ListClusters", "ecs:DescribeTaskDefinition", "ecs:RunTask",
        "logs:DescribeLogStreams", "logs:GetLogEvents", "logs:DescribeLogGroups",
        "iam:PassRole", "rds:DescribeDBInstances",
        "ec2:DescribeSecurityGroups", "ec2:CreateNetworkInterface",
        "ec2:AttachNetworkInterface", "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces", "ec2:DetachNetworkInterface",
        "ssm:DescribeInstanceInformation"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_custom_managed" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = aws_iam_policy.ecs_instance_combined_policy.arn
}

# ==========================================
# ECS Execution Role
# ==========================================

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-execution-role"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_default" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_ecr" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_policy" "ssm_parameter_access" {
  name = "${var.project_name}-ecs-ssm-parameter-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["ssm:GetParameters", "ssm:GetParameter"],
      Resource = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${var.project_name}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_ssm" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ssm_parameter_access.arn
}

resource "aws_iam_policy" "ecs_exec_logs_policy" {
  name = "${var.project_name}-ecs-exec-logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_logs_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_exec_logs_policy.arn
}

# ==========================================
# ECS Task Role
# ==========================================

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-task-role"
  })
}

resource "aws_iam_policy" "ecs_exec_policy" {
  name = "${var.project_name}-ecs-exec"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_policy_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
}
