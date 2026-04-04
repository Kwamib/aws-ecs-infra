# ==========================================
# Subnets
# ==========================================

# Public Subnets
resource "aws_subnet" "public_subnets" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.clixx_vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name    = each.value.name
    Type    = "Public"
    Purpose = each.value.purpose
  })
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
  for_each                = local.private_subnets
  vpc_id                  = aws_vpc.clixx_vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name    = each.value.name
    Type    = "Private"
    Purpose = each.value.purpose
  })
}
