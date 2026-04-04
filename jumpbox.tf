# ==========================================
# Bastion Host (Jump Box) — High Availability
# ==========================================

resource "aws_instance" "bastion" {
  count = 2

  ami                         = var.bastion_ami != "" ? var.bastion_ami : local.ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = local.bastion_subnets[count.index]
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  monitoring                  = true

  tags = merge(local.common_tags, {
    Name       = "${title(var.project_name)}-Bastion-AZ${count.index + 1}"
    Purpose    = "Bastion Host"
    AZ         = local.availability_zones[count.index]
    AMI_ID     = var.bastion_ami != "" ? var.bastion_ami : local.ami_id
    AMI_Source = var.bastion_ami != "" ? "manual" : "ssm"
  })

  depends_on = [
    aws_subnet.public_subnets,
    aws_internet_gateway.clixx_igw
  ]
}
