resource "aws_acm_certificate" "cert" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"

  # Optional: Add SANs (Subject Alternative Names) if required
  # subject_alternative_names = ["www.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  # Apply tags if required
  tags = merge(
    var.tags, var.tenant != "" ? { "Tenant" = var.tenant } : {}
  )
}

# Single validation record for the primary wildcard domain
output "acm_validation_record" {
  description = "Single ACM Certificate DNS Validation Record for the primary wildcard domain"
  value = one([
    for dvo in aws_acm_certificate.cert.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
    if dvo.domain_name == "*.${var.domain_name}"
  ])
}

# CREATED ONLY FOR WORKLOAD ACCOUNTS
# Create DNS records for certificate validation in Route 53
resource "aws_route53_record" "cert_validation_records" {
  for_each = var.workload ? {
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}

  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60

  lifecycle {
    create_before_destroy = true # Create new record before destroying the old one
  }
}

# After the DNS records are created, validate the certificate
resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = var.workload && var.acm_validation_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation_records : r.fqdn]

  depends_on = [aws_route53_record.cert_validation_records]

  timeouts {
    create = "5m"
  }
}

############################
# Additional domain names
# One wildcard cert (+ validation) per additional domain, keyed by domain.
############################
resource "aws_acm_certificate" "additional_certs" {
  for_each          = try(toset(var.additional_domain_names), {})
  domain_name       = "*.${each.key}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags, var.tenant != "" ? { "Tenant" = var.tenant } : {}
  )
}

# CREATED ONLY FOR WORKLOAD ACCOUNTS
# DNS validation records for each additional domain's wildcard cert.
resource "aws_route53_record" "additional_cert_validation_records" {
  for_each = var.workload ? {
    for item in flatten([
      for domain, cert in aws_acm_certificate.additional_certs : [
        for dvo in cert.domain_validation_options : {
          domain = domain
          name   = dvo.resource_record_name
          type   = dvo.resource_record_type
          value  = dvo.resource_record_value
        }
      ]
    ]) : item.domain => item
  } : {}

  zone_id = data.aws_route53_zone.additional[each.key].zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "additional_cert_validation" {
  for_each        = var.workload && var.acm_validation_enabled ? try(toset(var.additional_domain_names), toset([])) : toset([])
  certificate_arn = aws_acm_certificate.additional_certs[each.key].arn
  validation_record_fqdns = [
    aws_route53_record.additional_cert_validation_records[each.key].fqdn
  ]

  depends_on = [aws_route53_record.additional_cert_validation_records]

  timeouts {
    create = "5m"
  }
}
