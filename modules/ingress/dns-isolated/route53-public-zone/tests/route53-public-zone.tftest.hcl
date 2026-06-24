mock_provider "aws" {
  override_during = plan
}

run "dns_isolated_public_zone_plan" {
  command = plan

  variables {
    domain_name = "example.com"
    nlb_name    = "dualstack.example-nlb.eu-west-2.elb.amazonaws.com"
    nlb_zone    = "Z32O12XQLNTSW2"
  }

  assert {
    condition     = aws_route53_record.external_nlb.type == "A"
    error_message = "Expected Route53 record type A for isolated DNS module."
  }

  assert {
    condition     = aws_route53_record.external_nlb.name == "*.example.com"
    error_message = "Expected wildcard Route53 record name for the provided domain."
  }
}
