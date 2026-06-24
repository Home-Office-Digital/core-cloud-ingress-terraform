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
}

run "nlb_plan" {
  command = plan

  variables {
    vpc_name              = "example-vpc"
    private_subnet_filter = "example-private-*"
    tenant                = "test"
    ingress_lb_group_name = "test-ingress-group"
    external_ingress      = false
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

  assert {
    condition     = output.vpc_id == "vpc-12345678"
    error_message = "Expected mocked VPC id to be exposed via module output."
  }

  assert {
    condition     = length(output.private_subnets) == 3
    error_message = "Expected three mocked private subnet ids in output."
  }
}

run "nlb_plan_external_ingress_enabled" {
  command = plan

  variables {
    vpc_name              = "example-vpc"
    private_subnet_filter = "example-private-*"
    tenant                = "test"
    ingress_lb_group_name = "test-ingress-group"
    external_ingress      = true
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

  assert {
    condition     = output.vpc_id == "vpc-12345678"
    error_message = "Expected mocked VPC id to be exposed in enabled ingress path."
  }

  assert {
    condition     = length(output.private_subnets) == 3
    error_message = "Expected three mocked private subnets in enabled ingress path."
  }
}
