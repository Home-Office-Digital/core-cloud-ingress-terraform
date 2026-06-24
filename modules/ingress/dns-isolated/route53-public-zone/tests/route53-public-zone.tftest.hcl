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
}
