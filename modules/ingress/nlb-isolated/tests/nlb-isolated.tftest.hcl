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

run "nlb_isolated_plan" {
  command = plan

  variables {
    vpc_name              = "example-vpc"
    public_subnet_filter  = "example-public-*"
    tenant                = "test"
    ingress_lb_group_name = "test-ingress-group"
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

  assert {
    condition     = output.vpc_id == "vpc-12345678"
    error_message = "Expected mocked VPC id in nlb-isolated output."
  }

  assert {
    condition     = length(output.public_subnets) == 3
    error_message = "Expected three mocked public subnets in nlb-isolated output."
  }

}
