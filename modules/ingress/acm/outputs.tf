output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.cert.arn
}

# Map of additional domain => its wildcard ACM certificate ARN.
output "additional_acm_certificate_arns" {
  description = "Map of additional domain name to its ACM certificate ARN."
  value       = { for domain, cert in aws_acm_certificate.additional_certs : domain => cert.arn }
}

# Map of additional domain => its single ACM DNS validation record.
output "additional_acm_validation_records" {
  description = "Map of additional domain name to its ACM DNS validation record (name/type/value)."
  value = {
    for domain, cert in aws_acm_certificate.additional_certs : domain => one([
      for dvo in cert.domain_validation_options : {
        name  = dvo.resource_record_name
        type  = dvo.resource_record_type
        value = dvo.resource_record_value
      }
      if dvo.domain_name == "*.${domain}"
    ])
  }
}
