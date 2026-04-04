# ==========================================
# VPC Endpoints for ECS Private Connectivity
# ==========================================

locals {
  # Group private subnets by AZ, selecting one per AZ for endpoints
  private_subnets_for_endpoints = {
    for s in aws_subnet.private_subnets : s.availability_zone => s.id...
  }
}

# ECR API Endpoint (for image metadata)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.clixx_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for az, ids in local.private_subnets_for_endpoints : ids[0]]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-ECR-API-VPCE"
  })
}

# ECR Docker Endpoint (for image layer downloads)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.clixx_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for az, ids in local.private_subnets_for_endpoints : ids[0]]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-ECR-DKR-VPCE"
  })
}

# S3 Gateway Endpoint (for ECR image layer storage)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.clixx_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private_rt : rt.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:*"
      Resource  = "*"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-S3-VPCE"
  })
}
