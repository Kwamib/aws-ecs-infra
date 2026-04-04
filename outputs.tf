# ==========================================
# Core Network Outputs
# ==========================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.clixx_vpc.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public_subnets : subnet.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for subnet in aws_subnet.private_subnets : subnet.id]
}

output "private_subnet_map" {
  description = "Map of private subnet details by CIDR"
  value = {
    for k, v in local.private_subnets : k => {
      id                = aws_subnet.private_subnets[k].id
      cidr_block        = v.cidr_block
      availability_zone = v.availability_zone
      purpose           = v.purpose
      name              = v.name
    }
  }
}

# ==========================================
# ECS Outputs
# ==========================================

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.clixx_cluster.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.clixx_service.name
}

# ==========================================
# Load Balancer Outputs
# ==========================================

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.clixx_nlb.dns_name
}

output "target_group_80_arn" {
  description = "ARN of the port 80 target group"
  value       = aws_lb_target_group.clixx_nlb_tg_80.arn
}

output "target_group_443_arn" {
  description = "ARN of the port 443 target group"
  value       = aws_lb_target_group.clixx_nlb_tg_443.arn
}

# ==========================================
# Auto Scaling Group Outputs
# ==========================================

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg.name
}

# ==========================================
# RDS Outputs
# ==========================================

output "rds_endpoint" {
  description = "Connection endpoint for the RDS database"
  value       = aws_db_instance.clixx_db_from_snapshot.endpoint
}

output "rds_port" {
  description = "Port the RDS database accepts connections on"
  value       = aws_db_instance.clixx_db_from_snapshot.port
}

# ==========================================
# Bastion Host Outputs
# ==========================================

output "bastion_info" {
  description = "Bastion host connection details"
  value = {
    az1 = {
      instance_id = aws_instance.bastion[0].id
      public_ip   = aws_instance.bastion[0].public_ip
      private_ip  = aws_instance.bastion[0].private_ip
    }
    az2 = {
      instance_id = aws_instance.bastion[1].id
      public_ip   = aws_instance.bastion[1].public_ip
      private_ip  = aws_instance.bastion[1].private_ip
    }
  }
}

# ==========================================
# Application URL
# ==========================================

output "app_url" {
  description = "Application URL"
  value       = local.app_url
}
