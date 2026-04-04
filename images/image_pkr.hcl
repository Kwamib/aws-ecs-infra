variable "aws_source_ami" {
  default = "amzn2-ami-ecs-hvm-*-x86_64-ebs"
}

variable "aws_instance_type" {
  default = "t3.small"
}

variable "ami_name" {
  default = "ecs-app-ami"
}

variable "component" {
  default = "clixx"
}

variable "aws_accounts" {
  description = "AWS account IDs to share the AMI with"
  type        = list(string)
  default     = []
}

variable "version" {
  type        = string
  description = "AMI version number"
  default     = "1"
}

variable "ami_regions" {
  type    = list(string)
  default = ["us-east-1"]
}

variable "aws_region" {
  default = "us-east-1"
}

variable "assume_role_arn" {
  description = "IAM role ARN to assume for building the AMI"
  type        = string
  default     = ""
}

data "amazon-ami" "source_ami" {
  filters = {
    name = "${var.aws_source_ami}"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = "${var.aws_region}"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "amazon_ebs" {
  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }

  ami_name       = "${var.ami_name}-v${var.version}"
  ami_regions    = "${var.ami_regions}"
  ami_users      = "${var.aws_accounts}"
  snapshot_users = "${var.aws_accounts}"
  encrypt_boot   = false
  instance_type  = "${var.aws_instance_type}"

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = false
    volume_size           = 30
    volume_type           = "gp2"
  }

  region       = "${var.aws_region}"
  source_ami   = "${data.amazon-ami.source_ami.id}"
  ssh_pty      = true
  ssh_timeout  = "5m"
  ssh_username = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.amazon_ebs"]

  provisioner "shell" {
    script = "../scripts/setup.sh"
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}
