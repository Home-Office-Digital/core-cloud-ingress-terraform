mock_provider "aws" {
  override_during = plan
}

run "acm_plan" {
  command = plan

  variables {
    domain_name            = "example.com"
    tenant                 = "test"
    workload               = false
    acm_validation_enabled = false
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

}

run "acm_plan_empty_tenant" {
  command = plan

  variables {
    domain_name            = "example.com"
    tenant                 = ""
    workload               = false
    acm_validation_enabled = false
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

}
