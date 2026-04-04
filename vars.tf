# ==========================================
# Core AWS Configuration
# ==========================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "Development"

  validation {
    condition     = contains(["Development", "Staging", "Production"], var.environment)
    error_message = "Environment must be one of: Development, Staging, Production."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "clixx"
}

variable "assume_role_arn" {
  description = "IAM role ARN to assume for resource provisioning"
  type        = string
}

variable "domain_name" {
  description = "Base domain name for Route 53 and ACM (e.g., example.com)"
  type        = string
}

variable "app_subdomain" {
  description = "Subdomain for the ECS application (e.g., ecs)"
  type        = string
  default     = "ecs"
}

variable "owner_email" {
  description = "Email address for resource ownership tagging"
  type        = string
}

variable "team_name" {
  description = "Team name for resource tagging"
  type        = string
  default     = "platform-engineering"
}

# ==========================================
# VPC and Subnet Configuration
# ==========================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR blocks for public subnets (NLB, NAT gateways)"
  type        = list(string)
  default = [
    "10.0.0.0/23", # Web Tier AZ-A (512 hosts)
    "10.0.2.0/23"  # Web Tier AZ-B (512 hosts)
  ]
}

variable "private_subnet_cidr" {
  description = "CIDR blocks for private subnets (ECS tasks, databases)"
  type        = list(string)
  default = [
    "10.0.4.0/24",  # ECS App Tier 1 AZ-A
    "10.0.5.0/24",  # ECS App Tier 1 AZ-B
    "10.0.6.0/24",  # App Tier 2 AZ-A (reserved)
    "10.0.7.0/24",  # App Tier 2 AZ-B (reserved)
    "10.0.8.0/24",  # RDS Primary AZ-A
    "10.0.9.0/24",  # RDS Standby AZ-B
    "10.0.10.0/24", # Oracle AZ-A (reserved)
    "10.0.11.0/24", # Oracle AZ-B (reserved)
    "10.0.12.0/26", # Microservices AZ-A
    "10.0.12.64/26" # Microservices AZ-B
  ]
}

variable "az_mapping" {
  description = "Maps each subnet CIDR to its availability zone"
  type        = map(string)
  default = {
    "10.0.0.0/23"   = "us-east-1a"
    "10.0.2.0/23"   = "us-east-1b"
    "10.0.4.0/24"   = "us-east-1a"
    "10.0.5.0/24"   = "us-east-1b"
    "10.0.6.0/24"   = "us-east-1a"
    "10.0.7.0/24"   = "us-east-1b"
    "10.0.8.0/24"   = "us-east-1a"
    "10.0.9.0/24"   = "us-east-1b"
    "10.0.10.0/24"  = "us-east-1a"
    "10.0.11.0/24"  = "us-east-1b"
    "10.0.12.0/26"  = "us-east-1a"
    "10.0.12.64/26" = "us-east-1b"
  }
}

variable "default_az" {
  description = "Default availability zone fallback"
  type        = string
  default     = "us-east-1a"
}

# ==========================================
# EC2 / ECS Instance Configuration
# ==========================================

variable "ami_id" {
  description = "AMI ID for ECS container instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances"
  type        = string
  default     = "c4.large"

  validation {
    condition     = can(regex("^(t3|t2|m5|m4|c5|c4)\\.", var.instance_type))
    error_message = "Instance type must be from supported families (t3, t2, m5, m4, c5, c4)."
  }
}

variable "key_name" {
  description = "Name of the SSH key pair for EC2 access"
  type        = string
}

variable "trusted_ssh_cidr" {
  description = "CIDR block for trusted SSH access (restrict to your IP)"
  type        = string
  default     = "0.0.0.0/0"
}

# ==========================================
# ECS Container Configuration
# ==========================================

variable "container_image" {
  description = "ECR image URI for the application container"
  type        = string
}

variable "container_port" {
  description = "Port the container application listens on"
  type        = number
  default     = 80

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memory (MB) for the ECS task"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Desired number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "clixx-cluster"
}

variable "force_deploy" {
  description = "Whether to force a new ECS deployment"
  type        = bool
  default     = false
}

# ==========================================
# Auto Scaling Configuration
# ==========================================

variable "min_capacity" {
  description = "Minimum number of EC2 instances for ECS cluster"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of EC2 instances for ECS cluster"
  type        = number
  default     = 3
}

# ==========================================
# RDS Configuration
# ==========================================

variable "snapshot_identifier" {
  description = "RDS snapshot identifier to restore the database from"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"

  validation {
    condition     = can(regex("^db\\.", var.db_instance_class))
    error_message = "DB instance class must start with 'db.'."
  }
}

variable "db_username_ssm_param" {
  description = "SSM parameter name for the RDS username"
  type        = string
  default     = "/clixx/db_username"
}

variable "db_name_ssm_param" {
  description = "SSM parameter name for the database name"
  type        = string
  default     = "/clixx/wp_db_name"
}

# ==========================================
# Bastion Host Configuration
# ==========================================

variable "bastion_ami" {
  description = "AMI ID for bastion hosts"
  type        = string
  default     = ""
}

variable "bastion_instance_type" {
  description = "Instance type for bastion hosts"
  type        = string
  default     = "t2.micro"
}

# ==========================================
# Monitoring Configuration
# ==========================================

variable "notification_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}

# ==========================================
# Load Balancer Configuration
# ==========================================

variable "target_group_name" {
  description = "Name of the NLB target group"
  type        = string
  default     = "clixx-web-tg"
}

variable "wp_home_url" {
  description = "WordPress Home URL"
  type        = string
  default     = ""
}
