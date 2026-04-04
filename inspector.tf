# ==========================================
# AWS Inspector v2 — Vulnerability Scanning
# ==========================================

resource "aws_inspector2_enabler" "ec2" {
  account_ids    = [local.account_id]
  resource_types = ["EC2"]

  timeouts {
    create = "15m"
    update = "15m"
    delete = "10m"
  }

  lifecycle {
    ignore_changes = [resource_types]
  }
}

resource "aws_inspector2_enabler" "ecr" {
  account_ids    = [local.account_id]
  resource_types = ["ECR"]

  timeouts {
    create = "15m"
    update = "15m"
    delete = "10m"
  }

  lifecycle {
    ignore_changes = [resource_types]
  }
}

resource "aws_inspector2_filter" "critical_findings" {
  name   = "critical-vulnerabilities"
  action = "NONE"

  filter_criteria {
    finding_status {
      comparison = "EQUALS"
      value      = "ACTIVE"
    }

    severity {
      comparison = "EQUALS"
      value      = "CRITICAL"
    }
  }

  tags = merge(local.common_tags, {
    Name = "Critical Vulnerabilities Filter"
  })
}

output "inspector_v2_ec2_status" {
  description = "Inspector v2 EC2 scanning status"
  value       = aws_inspector2_enabler.ec2.id
}

output "inspector_v2_ecr_status" {
  description = "Inspector v2 ECR scanning status"
  value       = aws_inspector2_enabler.ecr.id
}
