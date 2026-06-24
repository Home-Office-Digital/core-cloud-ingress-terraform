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

  assert {
    condition     = aws_acm_certificate.cert.validation_method == "DNS"
    error_message = "Expected ACM certificate validation method to be DNS."
  }

  assert {
    condition     = aws_acm_certificate.cert.domain_name == "*.example.com"
    error_message = "Expected ACM certificate to use the wildcard domain."
  }

  assert {
    condition     = contains(keys(aws_acm_certificate.cert.tags), "Tenant")
    error_message = "Expected Tenant tag when tenant is set."
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

  assert {
    condition     = !contains(keys(aws_acm_certificate.cert.tags), "Tenant")
    error_message = "Expected no Tenant tag when tenant is empty."
  }

}
