# ==========================================
# Terraform Remote Backend Configuration
# ==========================================

terraform {
  backend "s3" {
    bucket  = "REPLACE-WITH-YOUR-STATE-BUCKET"
    key     = "ecs/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
