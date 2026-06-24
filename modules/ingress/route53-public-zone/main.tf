# Create Route53 A Record Alias for External ALB (only when external_ingress = true)
resource "aws_route53_record" "external_alb" {
  #checkov:skip=CKV2_AWS_23: Route53 A Record has Attached Resource
  count = (var.external_ingress && var.alb_dns_ready) ? 1 : 0

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.external_alb_dns   # e.g. my-alb-123.eu-west-1.elb.amazonaws.com
    zone_id                = var.alb_hosted_zone_id # e.g. data.aws_lb.external.zone_id
    evaluate_target_health = true
  }

  lifecycle {
    precondition {
      condition     = var.external_alb_dns != "" && var.alb_hosted_zone_id != ""
      error_message = "ALB DNS name/hosted zone ID must be set when creating the external ALB record."
    }
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = { for record in var.acm_records : record.name => record if length(var.acm_records) > 0 }

  zone_id = data.aws_route53_zone.selected.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}
