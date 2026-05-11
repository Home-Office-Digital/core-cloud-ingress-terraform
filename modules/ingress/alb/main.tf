############################
# Locals from data sources
############################
locals {
  vpc_id            = data.aws_vpcs.filtered_vpcs.ids[0]
  public_subnet_ids = data.aws_subnets.filtered_subnets.ids
  custom_listener_rules = {
    for rule in var.custom_listener_rules : rule.name => rule
  }
  oidc_client_secrets = {
    for rule_name, rule in local.custom_listener_rules :
    rule_name => (
      try(rule.oidc.client_secret, null) != null
      ? rule.oidc.client_secret
      : jsondecode(data.aws_secretsmanager_secret_version.oidc_client_secrets[rule_name].secret_string)[try(rule.oidc.client_secret_secret_json_key, "client_secret")]
    )
    if try(rule.oidc, null) != null
  }
}

############################
# Security Group (conditional)
############################
resource "aws_security_group" "alb_sg" {
  count = var.external_ingress ? 1 : 0
  name_prefix = var.tenant == "" ? (
    var.ingress_profile == "standard" ? "ingress-external-${var.account_id}-" : "ingress-external-${var.ingress_profile}-${var.account_id}-"
    ) : (
    var.ingress_profile == "standard" ? "${var.tenant}-ingress-external-${var.account_id}-" : "${var.tenant}-ingress-external-${var.ingress_profile}-${var.account_id}-"
  )
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
  count = var.external_ingress ? 1 : 0
  name = var.tenant == "" ? (
    var.ingress_profile == "standard" ? "ingress-external-${var.account_id}" : "ingress-external-${var.ingress_profile}-${var.account_id}"
    ) : (
    var.ingress_profile == "standard" ? "${var.tenant}-ingress-external-${var.account_id}" : "${var.tenant}-ingress-external-${var.ingress_profile}-${var.account_id}"
  )
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
    prefix = var.tenant == "" ? (
      var.ingress_profile == "standard" ? "${var.perimeter_account_id}/elb-ingress-external-${var.account_id}" : "${var.perimeter_account_id}/elb-ingress-external-${var.ingress_profile}-${var.account_id}"
      ) : (
      var.ingress_profile == "standard" ? "${var.perimeter_account_id}/elb-${var.tenant}-ingress-external-${var.account_id}" : "${var.perimeter_account_id}/elb-${var.tenant}-ingress-external-${var.ingress_profile}-${var.account_id}"
    )
  }
}

############################
# Target Group (conditional)
############################
resource "aws_lb_target_group" "tenant_target_group" {
  count = var.external_ingress ? 1 : 0
  name = var.tenant == "" ? (
    var.ingress_profile == "standard" ? "ingress-external-${var.account_id}-tg" : "ingress-external-${var.ingress_profile}-${var.account_id}-tg"
    ) : (
    var.ingress_profile == "standard" ? "${var.tenant}-ingress-external-${var.account_id}-tg" : "${var.tenant}-ingress-external-${var.ingress_profile}-${var.account_id}-tg"
  )
  port             = 443
  protocol         = "HTTPS"
  protocol_version = "HTTP1"
  target_type      = "ip"
  vpc_id           = local.vpc_id
  tags             = var.tags

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

resource "aws_lb_target_group" "tenant_target_group_http2" {
  count = var.external_ingress && var.ingress_profile == "custom" ? 1 : 0
  name = var.tenant == "" ? (
    "ingress-external-${var.account_id}-h2-tg"
    ) : (
    "${var.tenant}-ingress-external-${var.account_id}-h2-tg"
  )
  port             = 443
  protocol         = "HTTPS"
  protocol_version = "HTTP2"
  target_type      = "ip"
  vpc_id           = local.vpc_id
  tags             = var.tags

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
  for_each          = var.external_ingress ? toset(var.workload_external_nlb_ips) : []
  target_group_arn  = aws_lb_target_group.tenant_target_group[0].arn
  target_id         = each.value
  port              = 443
  availability_zone = "all"
}

resource "aws_lb_target_group_attachment" "tg_attachment_http2" {
  for_each = var.external_ingress && var.ingress_profile == "custom" ? toset(var.workload_external_nlb_ips) : []

  target_group_arn  = aws_lb_target_group.tenant_target_group_http2[0].arn
  target_id         = each.value
  port              = 443
  availability_zone = "all"
}

############################
# HTTPS Listener (conditional)
############################
resource "aws_lb_listener" "https_listener" {
  count             = var.external_ingress ? 1 : 0
  load_balancer_arn = aws_lb.tenant_alb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = var.ingress_profile == "custom" ? aws_lb_target_group.tenant_target_group_http2[0].arn : aws_lb_target_group.tenant_target_group[0].arn
  }

  tags = var.tags
}

############################
# Custom Listener Rules (custom profile)
############################
resource "aws_lb_listener_rule" "custom_profile_rules" {
  for_each = var.external_ingress && var.ingress_profile != "standard" ? local.custom_listener_rules : {}

  listener_arn = aws_lb_listener.https_listener[0].arn
  priority     = each.value.priority

  dynamic "action" {
    for_each = each.value.oidc == null ? [] : [each.value.oidc]
    content {
      type = "authenticate-oidc"

      authenticate_oidc {
        authorization_endpoint              = action.value.authorization_endpoint
        client_id                           = action.value.client_id
        client_secret                       = local.oidc_client_secrets[each.key]
        issuer                              = action.value.issuer
        token_endpoint                      = action.value.token_endpoint
        user_info_endpoint                  = action.value.user_info_endpoint
        on_unauthenticated_request          = action.value.on_unauthenticated_request
        scope                               = action.value.scope
        session_cookie_name                 = action.value.session_cookie_name
        session_timeout                     = action.value.session_timeout
        authentication_request_extra_params = action.value.authentication_request_extra_params
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = each.value.target_group_type == "http1" ? aws_lb_target_group.tenant_target_group[0].arn : aws_lb_target_group.tenant_target_group_http2[0].arn
  }

  dynamic "condition" {
    for_each = length(each.value.host_headers) > 0 ? [each.value.host_headers] : []
    content {
      host_header {
        values = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = length(each.value.path_patterns) > 0 ? [each.value.path_patterns] : []
    content {
      path_pattern {
        values = condition.value
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(each.value.host_headers) > 0 || length(each.value.path_patterns) > 0
      error_message = "Each custom_listener_rules entry must define at least one condition via host_headers or path_patterns."
    }
    precondition {
      condition     = contains(["http1", "http2"], each.value.target_group_type)
      error_message = "custom_listener_rules.target_group_type must be either http1 or http2."
    }
    precondition {
      condition     = each.value.oidc == null || each.value.target_group_type == "http1"
      error_message = "OIDC-enabled rules must target the http1 target group."
    }
    precondition {
      condition = each.value.oidc == null || (
        (try(each.value.oidc.client_secret, null) != null) !=
        (try(each.value.oidc.client_secret_secret_arn, null) != null)
      )
      error_message = "OIDC rules must define exactly one secret source: oidc.client_secret or oidc.client_secret_secret_arn."
    }
  }

  tags = var.tags
}

############################
# Optional wait (conditional)
############################
resource "time_sleep" "wait_60_seconds" {
  count           = var.external_ingress ? 1 : 0
  depends_on      = [aws_lb.tenant_alb]
  create_duration = "60s"
}
