# ==========================================
# NAT Gateway Configuration
# ==========================================

resource "aws_eip" "nat_eip" {
  for_each = toset(var.public_subnet_cidr)
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-NAT-EIP-${each.key}"
  })
}

resource "aws_nat_gateway" "clixx_nat" {
  for_each = toset(var.public_subnet_cidr)

  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = aws_subnet.public_subnets[each.key].id

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-NAT-${each.key}"
  })
}
