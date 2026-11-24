mock_provider "aws" {
  override_during = plan

  mock_data "aws_vpcs" {
    defaults = {
      ids = ["vpc-12345678"]
    }
  }

  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
    }
  }

  mock_data "aws_lb_hosted_zone_id" {
    defaults = {
      id = "Z32O12XQLNTSW2"
    }
  }
}

mock_provider "time" {
  override_during = plan
}

run "custom_alb_plan" {
  command = plan

  variables {
    external_ingress     = false
    domain_name          = "example.com"
    tenant               = "test"
    account_id           = "111111111111"
    perimeter_account_id = "222222222222"
    vpc_name             = "example-vpc"
    public_subnet_filter = "example-public-*"
    acm_certificate_arn  = "arn:aws:acm:eu-west-2:111111111111:certificate/00000000-0000-0000-0000-000000000000"
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

  assert {
    condition     = output.alb_dns_name == "no-public-ingress-no-perimeter-alb"
    error_message = "Expected placeholder ALB DNS output when external_ingress is false."
  }

  assert {
    condition     = length(output.alb_hosted_zone_id) > 0
    error_message = "Expected ALB hosted zone id output to be populated."
  }
}

run "custom_alb_plan_external_ingress_enabled" {
  command = plan

  variables {
    external_ingress     = true
    domain_name          = "example.com"
    tenant               = "test"
    account_id           = "111111111111"
    perimeter_account_id = "222222222222"
    vpc_name             = "example-vpc"
    public_subnet_filter = "example-public-*"
    acm_certificate_arn  = "arn:aws:acm:eu-west-2:111111111111:certificate/00000000-0000-0000-0000-000000000000"
    workload_external_nlb_ips = [
      "10.10.1.10",
      "10.10.2.10",
      "10.10.3.10",
    ]
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

  assert {
    condition     = length(output.alb_hosted_zone_id) > 0
    error_message = "Expected ALB hosted zone id output to be populated when external_ingress is enabled."
  }

}
run "custom_alb_no_web_acl_by_default" {
  command = plan
  variables {
    external_ingress          = true
    domain_name               = "example.com"
    tenant                    = "test"
    account_id                = "111111111111"
    perimeter_account_id      = "222222222222"
    vpc_name                  = "example-vpc"
    public_subnet_filter      = "example-public-*"
    acm_certificate_arn       = "arn:aws:acm:eu-west-2:111111111111:certificate/00000000-0000-0000-0000-000000000000"
    workload_external_nlb_ips = ["10.10.1.10", "10.10.2.10", "10.10.3.10"]
    tags = {
      Environment = "test"
    }
  }
  assert {
    condition     = length(aws_wafv2_web_acl.tenant_alb) == 0 && length(aws_wafv2_web_acl_association.tenant_alb) == 0
    error_message = "No module-managed Web ACL must be created unless create_web_acl is true."
  }
  assert {
    condition     = length(aws_cloudwatch_log_group.tenant_alb_waf) == 0 && length(aws_wafv2_web_acl_logging_configuration.tenant_alb) == 0
    error_message = "No WAF log group or logging configuration must be created unless create_web_acl is true."
  }
}
run "custom_alb_web_acl_opt_in" {
  command = plan
  variables {
    external_ingress          = true
    create_web_acl            = true
    domain_name               = "example.com"
    tenant                    = "test"
    account_id                = "111111111111"
    perimeter_account_id      = "222222222222"
    vpc_name                  = "example-vpc"
    public_subnet_filter      = "example-public-*"
    acm_certificate_arn       = "arn:aws:acm:eu-west-2:111111111111:certificate/00000000-0000-0000-0000-000000000000"
    workload_external_nlb_ips = ["10.10.1.10", "10.10.2.10", "10.10.3.10"]
    tags = {
      Environment = "test"
    }
  }
  assert {
    condition     = length(aws_wafv2_web_acl.tenant_alb) == 1 && length(aws_wafv2_web_acl_association.tenant_alb) == 1
    error_message = "Module-managed Web ACL and association must be created when create_web_acl is true."
  }
  assert {
    condition     = length(aws_cloudwatch_log_group.tenant_alb_waf) == 1 && length(aws_wafv2_web_acl_logging_configuration.tenant_alb) == 1
    error_message = "WAF log group and logging configuration must be created when create_web_acl is true."
  }
}
