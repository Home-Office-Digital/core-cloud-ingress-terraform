mock_provider "aws" {
  override_during = plan

  mock_data "aws_vpcs" {
    defaults = {
      ids = ["vpc-12345678"]
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-12345678"
      cidr_block = "10.0.0.0/24"
    }
  }
}

run "private_subnets_plan" {
  command = plan

  variables {
    vpc_name = "example-vpc"
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }

  assert {
    condition     = can(output.subnet_names_and_cidrs)
    error_message = "Expected subnet_names_and_cidrs output to be available."
  }
}
