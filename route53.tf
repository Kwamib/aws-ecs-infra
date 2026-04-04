# ==========================================
# Route 53 DNS Configuration
# ==========================================

data "aws_route53_zone" "selected" {
  name         = "${var.domain_name}."
  private_zone = false
}

resource "aws_route53_record" "clixx" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.clixx_nlb.dns_name
    zone_id                = aws_lb.clixx_nlb.zone_id
    evaluate_target_health = true
  }
}
