resource "aws_vpc_endpoint_service" "default" {
  acceptance_required        = var.acceptance_required
  allowed_principals         = var.allowed_principals
  network_load_balancer_arns = var.network_load_balancer_arns
  private_dns_name           = var.private_dns_name
}

resource "aws_vpc_endpoint_service_allowed_principal" "default" {
  for_each                = var.principal_arns
  principal_arn           = each.key
  vpc_endpoint_service_id = aws_vpc_endpoint_service.default.id
}

resource "aws_vpc_endpoint_service_private_dns_verification" "default" {
  count                 = var.private_dns_verification ? 1 : 0
  service_id            = aws_vpc_endpoint_service.default.id
  wait_for_verification = var.private_dns_verification
}
