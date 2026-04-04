# ==========================================
# Security Groups
# ==========================================

# Public Security Group
resource "aws_security_group" "public_sg" {
  name        = "${var.project_name}-public-sg"
  description = "Security group for public instances"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-Public-SG"
  })
}

# Bastion Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH from trusted IP"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-Bastion-SG"
  })
}

# ASG Instance Security Group (NLB — Layer 4, no SG filtering)
resource "aws_security_group" "asg_sg" {
  name        = "${var.project_name}-asg-sg"
  description = "Security group for EC2 instances behind NLB"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    description = "HTTP from NLB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from NLB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-ASG-SG"
  })
}

# Restrictive ASG SG (limits traffic to NLB subnet CIDRs only)
resource "aws_security_group" "asg_sg_restrictive" {
  name        = "${var.project_name}-asg-sg-restrictive"
  description = "Restrictive SG for EC2 instances behind NLB"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    description = "HTTP from NLB subnets"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.public_subnets : subnet.cidr_block]
  }

  ingress {
    description = "HTTPS from NLB subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.public_subnets : subnet.cidr_block]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-ASG-SG-Restrictive"
  })
}

# ECS Task Security Group (awsvpc mode — each task gets its own ENI)
resource "aws_security_group" "clixx_task_sg" {
  name        = "${var.project_name}-task-sg"
  description = "SG for ECS tasks in awsvpc mode"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    description = "HTTP from NLB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from NLB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-task-sg"
  })
}

# Database Security Group
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg-${var.environment}"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    description     = "MySQL from ASG instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.asg_sg.id]
  }

  ingress {
    description     = "MySQL from ECS Tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.clixx_task_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-DB-SG"
  })
}

# VPC Endpoint Security Group
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${var.project_name}-vpc-endpoint-sg"
  description = "Allow HTTPS from ECS tasks and ASG to VPC endpoints"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    description = "HTTPS from ECS Tasks and ASG"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [
      aws_security_group.clixx_task_sg.id,
      aws_security_group.asg_sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-VPC-Endpoint-SG"
  })
}
