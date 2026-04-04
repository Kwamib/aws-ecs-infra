# ==========================================
# RDS Database Configuration
# ==========================================

resource "aws_db_parameter_group" "clixx_db_params" {
  name   = "${var.project_name}-db-params-${local.env_name_normalized}"
  family = "mysql8.0"

  parameter {
    name  = "max_connections"
    value = var.environment == "Production" ? "1000" : "100"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)} DB Parameters"
  })
}

resource "aws_db_subnet_group" "clixx_db_subnet_group" {
  name        = "${var.project_name}-db-subnet-group-${local.env_name_normalized}"
  description = "DB subnet group for ${var.project_name}"
  subnet_ids  = [for subnet in aws_subnet.private_subnets : subnet.id]

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)} DB Subnet Group"
  })
}

resource "aws_db_instance" "clixx_db_from_snapshot" {
  identifier          = "${var.project_name}-db-${local.env_name_normalized}"
  snapshot_identifier = data.aws_db_snapshot.clixx_snapshot.id
  instance_class      = var.db_instance_class

  db_subnet_group_name   = aws_db_subnet_group.clixx_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false

  apply_immediately    = lower(var.environment) == "development"
  backup_window        = "03:00-04:00"
  maintenance_window   = "Mon:04:30-Mon:05:30"
  parameter_group_name = aws_db_parameter_group.clixx_db_params.name
  skip_final_snapshot  = true
  port                 = 3306

  tags = merge(local.common_tags, {
    Name        = "${title(var.project_name)}-Database"
    Application = "${title(var.project_name)} Web App"
    RestoreDate = formatdate("YYYY-MM-DD", timestamp())
  })
}

resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/${var.project_name}/db_host"
  description = "${title(var.project_name)} Database Endpoint"
  type        = "SecureString"
  value       = aws_db_instance.clixx_db_from_snapshot.address
  overwrite   = true

  tags = merge(local.common_tags, {
    Application = "${title(var.project_name)} Web App"
  })
}
