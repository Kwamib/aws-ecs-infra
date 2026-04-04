# ==========================================
# Internet Gateway
# ==========================================

resource "aws_internet_gateway" "clixx_igw" {
  vpc_id = aws_vpc.clixx_vpc.id

  tags = merge(local.common_tags, {
    Name = "${title(var.project_name)}-IGW"
  })
}
