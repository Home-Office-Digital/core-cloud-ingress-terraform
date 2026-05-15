############################
# Locals from data sources
############################
locals {
  vpc_id            = data.aws_vpcs.filtered_vpcs.ids[0]
  public_subnet_ids = data.aws_subnets.filtered_subnets.ids

  raw_custom_listener_rules = {
    for rule in var.custom_listener_rules : rule.ruleName => rule
  }

  forward_target_group_names = {
    for rule_name, rule in local.raw_custom_listener_rules :
    rule_name => try(one([for action in rule.actions : action.targetGroupName if action.type == "forward"]), "")
  }

  oidc_actions = {
    for rule_name, rule in local.raw_custom_listener_rules :
    rule_name => try(one([for action in rule.actions : action.authenticateOidcConfig if action.type == "authenticate-oidc"]), null)
  }

  custom_listener_rules = {
    for rule_name, rule in local.raw_custom_listener_rules :
    rule_name => {
      priority = rule.priority
      target_group_type = (
        can(regex("http1", lower(local.forward_target_group_names[rule_name])))
        ? "http1"
        : can(regex("http2", lower(local.forward_target_group_names[rule_name])))
        ? "http2"
        : "invalid"
      )
      host_headers = flatten([
        for condition in rule.conditions :
        condition.field == "host-header"
        ? try(condition.hostHeaderConfig.values, try(condition.values, []))
        : []
      ])
      path_patterns = flatten([
        for condition in rule.conditions :
        condition.field == "path-pattern"
        ? try(condition.values, [])
        : []
      ])
      source_ips = flatten([
        for condition in rule.conditions :
        condition.field == "source-ip"
        ? try(condition.sourceIpConfig.values, try(condition.values, []))
        : []
      ])
      http_header_conditions = [
        for condition in rule.conditions : {
          name   = condition.httpHeaderConfig.httpHeaderName
          values = condition.httpHeaderConfig.values
        }
        if condition.field == "http-header"
      ]
      oidc = local.oidc_actions[rule_name] == null ? null : {
        authorization_endpoint              = local.oidc_actions[rule_name].authorizationEndpoint
        client_id                           = local.oidc_actions[rule_name].clientId
        client_secret                       = try(local.oidc_actions[rule_name].clientSecret, null)
        client_secret_secret_arn            = try(local.oidc_actions[rule_name].clientSecretSecretArn, null)
        client_secret_secret_json_key       = try(local.oidc_actions[rule_name].clientSecretSecretJsonKey, "client_secret")
        issuer                              = local.oidc_actions[rule_name].issuer
        token_endpoint                      = local.oidc_actions[rule_name].tokenEndpoint
        user_info_endpoint                  = local.oidc_actions[rule_name].userInfoEndpoint
        on_unauthenticated_request          = try(local.oidc_actions[rule_name].onUnauthenticatedRequest, "authenticate")
        scope                               = try(local.oidc_actions[rule_name].scope, "openid")
        session_cookie_name                 = try(local.oidc_actions[rule_name].sessionCookieName, "AWSELBAuthSessionCookie")
        session_timeout                     = try(local.oidc_actions[rule_name].sessionTimeout, 604800)
        authentication_request_extra_params = try(local.oidc_actions[rule_name].authenticationRequestExtraParams, {})
      }
    }
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
# Security Group
############################
resource "aws_security_group" "alb_sg" {
  name_prefix = var.tenant == "" ? "ingress-external-custom-${var.account_id}-" : "${var.tenant}-ingress-external-custom-${var.account_id}-"
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
# ALB
############################
#checkov:skip=CKV2_AWS_76: False positive - ALB is explicitly associated to a REGIONAL Web ACL that includes AWSManagedRulesKnownBadInputsRuleSet for Log4j coverage.
resource "aws_lb" "tenant_alb" {
  name               = var.tenant == "" ? "ingress-external-custom-${var.account_id}" : "${var.tenant}-ingress-external-custom-${var.account_id}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.public_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = true
  tags                       = var.tags

  access_logs {
    enabled = true
    bucket  = "aws-accelerator-elb-access-logs-905418430070-eu-west-2"
    prefix  = var.tenant == "" ? "${var.perimeter_account_id}/elb-ingress-external-custom-${var.account_id}" : "${var.perimeter_account_id}/elb-${var.tenant}-ingress-external-custom-${var.account_id}"
  }
}

#checkov:skip=CKV2_AWS_76: False positive - this Web ACL includes AWS managed rule coverage for known bad inputs including Log4j signatures.
resource "aws_wafv2_web_acl" "tenant_alb" {
  name  = var.tenant == "" ? "ingress-external-custom-${var.account_id}-waf" : "${var.tenant}-ingress-external-custom-${var.account_id}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.tenant == "" ? "ingress-external-custom-${var.account_id}-waf" : "${var.tenant}-ingress-external-custom-${var.account_id}-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

#checkov:skip=CKV2_AWS_76: False positive - association directly attaches aws_wafv2_web_acl.tenant_alb to aws_lb.tenant_alb.
resource "aws_wafv2_web_acl_association" "tenant_alb" {
  resource_arn = aws_lb.tenant_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.tenant_alb.arn
}

resource "aws_cloudwatch_log_group" "tenant_alb_waf" {
  name              = var.tenant == "" ? "aws-waf-logs-ingress-external-custom-${var.account_id}" : "aws-waf-logs-${var.tenant}-ingress-external-custom-${var.account_id}"
  retention_in_days = var.waf_log_retention_in_days
  kms_key_id        = var.waf_log_kms_key_id != "" ? var.waf_log_kms_key_id : data.aws_kms_alias.cloudwatch_logs.target_key_arn
  tags              = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "tenant_alb" {
  log_destination_configs = [aws_cloudwatch_log_group.tenant_alb_waf.arn]
  resource_arn            = aws_wafv2_web_acl.tenant_alb.arn
}

############################
# Target Groups
############################
resource "aws_lb_target_group" "tenant_target_group" {
  name             = var.tenant == "" ? "ingress-custom-${var.account_id}-tg" : "${var.tenant}-ingress-custom-${var.account_id}-tg"
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
  name             = var.tenant == "" ? "ingress-custom-${var.account_id}-h2-tg" : "${var.tenant}-ingress-custom-${var.account_id}-h2-tg"
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
# Register NLB IPs
############################
resource "aws_lb_target_group_attachment" "tg_attachment" {
  for_each          = toset(var.workload_external_nlb_ips)
  target_group_arn  = aws_lb_target_group.tenant_target_group.arn
  target_id         = each.value
  port              = 443
  availability_zone = "all"
}

resource "aws_lb_target_group_attachment" "tg_attachment_http2" {
  for_each          = toset(var.workload_external_nlb_ips)
  target_group_arn  = aws_lb_target_group.tenant_target_group_http2.arn
  target_id         = each.value
  port              = 443
  availability_zone = "all"
}

############################
# HTTPS Listener
############################
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.tenant_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tenant_target_group_http2.arn
  }

  tags = var.tags
}

############################
# Custom Listener Rules
############################
resource "aws_lb_listener_rule" "custom_profile_rules" {
  for_each = local.custom_listener_rules

  listener_arn = aws_lb_listener.https_listener.arn
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
    target_group_arn = each.value.target_group_type == "http1" ? aws_lb_target_group.tenant_target_group.arn : aws_lb_target_group.tenant_target_group_http2.arn
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

  dynamic "condition" {
    for_each = length(try(each.value.source_ips, [])) > 0 ? [each.value.source_ips] : []
    content {
      source_ip {
        values = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = try(each.value.http_header_conditions, [])
    content {
      http_header {
        http_header_name = condition.value.name
        values           = condition.value.values
      }
    }
  }

  lifecycle {
    precondition {
      condition = (
        length(each.value.host_headers) > 0 ||
        length(each.value.path_patterns) > 0 ||
        length(try(each.value.source_ips, [])) > 0 ||
        length(try(each.value.http_header_conditions, [])) > 0
      )
      error_message = "Each custom_listener_rules entry must define at least one condition via host_headers, path_patterns, source_ips, or http_header_conditions."
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
# Optional wait
############################
resource "time_sleep" "wait_60_seconds" {
  depends_on      = [aws_lb.tenant_alb]
  create_duration = "60s"
}
