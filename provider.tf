# ==========================================
# AWS Provider Configuration
# ==========================================

provider "aws" {
  alias  = "ssm"
  region = var.aws_region
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "terraform-deploy"
  }
}
