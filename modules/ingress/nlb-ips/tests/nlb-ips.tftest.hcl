mock_provider "aws" {
  override_during = plan
}

run "nlb_ips_plan" {
  command = plan

  variables {
    ingress_lb_group_name = "test-ingress-group"
    external_ingress      = false
  }
}

run "nlb_ips_plan_external_ingress_enabled" {
  command = plan

  variables {
    ingress_lb_group_name = "test-ingress-group"
    external_ingress      = true
  }

  assert {
    condition     = can(output.aws_external_nlb_network_interface_ips)
    error_message = "Expected aws_external_nlb_network_interface_ips output to be available when external_ingress is enabled."
  }
}
