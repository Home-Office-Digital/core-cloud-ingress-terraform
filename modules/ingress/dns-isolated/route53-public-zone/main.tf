#checkov:skip=CKV2_AWS_23: Route53 A Record has Attached Resource
resource "aws_route53_record" "external_nlb" {
  zone_id = data.aws_route53_zone.selected.zone_id # This is for the Route 53 hosted zone
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.nlb_name
    zone_id                = var.nlb_zone
    evaluate_target_health = true
  }
}
