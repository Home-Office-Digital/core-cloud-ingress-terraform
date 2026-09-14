data "aws_route53_zone" "selected" {
  count = var.workload ? 1 : 0
  name  = var.domain_name
}

# Per-additional-domain hosted zone lookups (workload accounts only), keyed by domain.
data "aws_route53_zone" "additional" {
  for_each = var.workload ? toset(var.additional_domain_names) : toset([])
  name     = each.key
}
