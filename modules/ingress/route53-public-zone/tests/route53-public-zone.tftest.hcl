mock_provider "aws" {
  override_during = plan
}

run "route53_public_zone_plan" {
  command = plan

  variables {
    domain_name      = "example.com"
    external_ingress = false
    alb_dns_ready    = false
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

  assert {
    condition     = length(output.acm_records) == 0
    error_message = "Expected no ACM Route53 validation records when external ingress is disabled."
  }
}

run "route53_public_zone_plan_external_ingress_enabled" {
  command = plan

  variables {
    domain_name        = "example.com"
    external_ingress   = true
    alb_dns_ready      = true
    external_alb_dns   = "alb.example.eu-west-2.elb.amazonaws.com"
    alb_hosted_zone_id = "Z32O12XQLNTSW2"
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

  assert {
    condition     = length(output.acm_records) == 0
    error_message = "Expected no ACM validation records when acm_records input is not provided."
  }
}
