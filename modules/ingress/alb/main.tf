############################
# Locals from data sources
############################
locals {
  vpc_id            = data.aws_vpcs.filtered_vpcs.ids[0]
  public_subnet_ids = data.aws_subnets.filtered_subnets.ids
}

############################
# Security Group (conditional)
############################
resource "aws_security_group" "alb_sg" {
  count       = var.ingress_profile != "standard" ? 1 : 0
  name_prefix = var.tenant == "" ? "ingress-${var.ingress_profile}-${var.account_id}-" : "${var.tenant}-${var.ingress_profile}-${var.account_id}-"
  description = "Allow inbound traffic to ALB"
  vpc_id      = local.vpc_id
  tags        = var.tags

  ingress {
    description = "Allow traffic from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow traffic from ALB to NLBs in workload accounts"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/16"]
  }
}

############################
# ALB (conditional)
############################
resource "aws_lb" "tenant_alb" {
  count              = var.ingress_profile != "standard" ? 1 : 0
  name               = var.tenant == "" ? "ingress-${var.ingress_profile}-${var.account_id}" : "${var.tenant}-${var.ingress_profile}-${var.account_id}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg[0].id]
  subnets            = local.public_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = false
  tags                       = var.tags

  access_logs {
    enabled = true
    bucket  = "aws-accelerator-elb-access-logs-905418430070-eu-west-2"
    prefix  = var.tenant == "" ? "${var.perimeter_account_id}/elb-ingress-${var.ingress_profile}-${var.account_id}" : "${var.perimeter_account_id}/elb-${var.tenant}-${var.ingress_profile}-${var.account_id}"
  }

}

############################
# Target Group (conditional)
############################
resource "aws_lb_target_group" "tenant_target_group" {
  count       = var.ingress_profile != "standard" ? 1 : 0
  name        = var.tenant == "" ? "ingress-${var.ingress_profile}-${var.account_id}-tg" : "${var.tenant}-${var.ingress_profile}-${var.account_id}-tg"
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"
  vpc_id      = local.vpc_id
  tags        = var.tags

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTPS"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200,404"
  }
}

############################
# Register NLB IPs (conditional)
############################
resource "aws_lb_target_group_attachment" "tg_attachment" {
  for_each          = var.ingress_profile != "standard" ? toset(var.workload_external_nlb_ips) : []
  target_group_arn  = aws_lb_target_group.tenant_target_group[0].arn
  target_id         = each.value
  port              = 443
  availability_zone = "all"
}

############################
# HTTPS Listener (conditional)
############################
resource "aws_lb_listener" "https_listener" {
  count             = var.ingress_profile != "standard" ? 1 : 0
  load_balancer_arn = aws_lb.tenant_alb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tenant_target_group[0].arn
  }

  tags = var.tags
}

############################
# Optional wait (conditional)
############################
resource "time_sleep" "wait_60_seconds" {
  count           = var.ingress_profile != "standard" ? 1 : 0
  depends_on      = [aws_lb.tenant_alb]
  create_duration = "60s"
}
