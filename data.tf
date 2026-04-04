# ==========================================
# Core AWS Data Sources
# ==========================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }
}

# ==========================================
# ACM Certificate
# ==========================================

data "aws_acm_certificate" "clixx_cert" {
  domain      = "*.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

# ==========================================
# RDS Snapshot
# ==========================================

data "aws_db_snapshot" "clixx_snapshot" {
  db_snapshot_identifier = var.snapshot_identifier
  most_recent            = true
}

# ==========================================
# SSM Parameters (Database Secrets)
# ==========================================

data "aws_ssm_parameter" "wp_db_name" {
  name            = var.db_name_ssm_param
  with_decryption = true
}

data "aws_ssm_parameter" "wp_db_user" {
  name            = "/${var.project_name}/wp_db_user"
  with_decryption = true
}

data "aws_ssm_parameter" "db_password" {
  name            = "/${var.project_name}/clixx_db_password"
  with_decryption = true
}

# ==========================================
# ASG Instance Lookup
# ==========================================

data "aws_autoscaling_groups" "clixx_asg" {
  names      = [aws_autoscaling_group.clixx_asg.name]
  depends_on = [aws_autoscaling_group.clixx_asg]
}

data "aws_instances" "clixx_asg_instances" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  filter {
    name   = "instance.group-name"
    values = [data.aws_autoscaling_groups.clixx_asg.names[0]]
  }

  depends_on = [aws_autoscaling_group.clixx_asg]
}

# ==========================================
# Public Subnet Lookup
# ==========================================

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.clixx_vpc.id]
  }

  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}
