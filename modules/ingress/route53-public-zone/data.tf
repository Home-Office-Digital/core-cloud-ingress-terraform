data "aws_route53_zone" "selected" {
  name = var.domain_name
}

# Per-additional-domain hosted zone lookups, keyed by domain.
data "aws_route53_zone" "additional" {
  for_each = toset(var.additional_domain_names)
  name     = each.key
}
