resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.domain_name
  tags  = var.tags
}

data "aws_route53_zone" "existing" {
  count        = var.create_hosted_zone ? 0 : 1
  name         = var.domain_name
  private_zone = false
}

locals {
  zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

resource "aws_route53_record" "alb_alias" {
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
