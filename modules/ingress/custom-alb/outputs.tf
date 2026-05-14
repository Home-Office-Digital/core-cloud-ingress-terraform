# ALB-specific outputs
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.tenant_alb.dns_name
}

output "alb_hosted_zone_id" {
  description = "Hosted zone ID for ALB DNS names in this region"
  value       = data.aws_lb_hosted_zone_id.main.id
}

# Data-source outputs are always safe
output "vpc_id" {
  description = "VPC ID matched by var.vpc_name"
  value       = local.vpc_id
}

output "public_subnets" {
  description = "Subnet IDs matched by var.public_subnet_filter in the selected VPC"
  value       = local.public_subnet_ids
}
