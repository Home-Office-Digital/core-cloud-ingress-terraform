# Fetch VPC ID based on its Name tag
data "aws_vpcs" "filtered_vpcs" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Fetch public subnets based on the Name tag and VPC
data "aws_subnets" "filtered_subnets" {
  filter {
    name   = "tag:Name"
    values = [var.public_subnet_filter]
  }

  filter {
    name   = "vpc-id"
    values = data.aws_vpcs.filtered_vpcs.ids
  }
}

# Hosted zone ID used by ALB DNS names in this region
data "aws_lb_hosted_zone_id" "main" {}

# Resolve OIDC client secrets from Secrets Manager for custom listener rules.
data "aws_secretsmanager_secret_version" "oidc_client_secrets" {
  for_each = {
    for rule_name, rule in local.custom_listener_rules : rule_name => rule
    if try(rule.oidc.client_secret_secret_arn, null) != null
  }

  secret_id = each.value.oidc.client_secret_secret_arn
}
