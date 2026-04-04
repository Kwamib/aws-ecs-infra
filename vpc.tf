# ==========================================
# VPC Configuration
# ==========================================

resource "aws_vpc" "clixx_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-VPC"
  })
}
