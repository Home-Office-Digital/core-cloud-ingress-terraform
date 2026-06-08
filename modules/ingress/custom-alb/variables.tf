variable "external_ingress" {
  description = "If false, do not create any external ingress resources"
  type        = bool
  default     = false
}

variable "workload_external_nlb_ips" {
  description = "List of External NLB IPs"
  type        = list(string)
  default     = ["1.2.3.4", "5.6.7.8", "9.1.2.3"]
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to AWS resources"
  default     = {}
}

variable "domain_name" {
  description = "The domain name for the hosted zone"
  type        = string
}

variable "tenant" {
  description = "The tenant name"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "perimeter_account_id" {
  description = "AWS Perimeter Account ID"
  type        = string
}

variable "public_subnet_filter" {
  description = "Name tag filter for public subnets"
  type        = string
  default     = "cc-ingress-notprod-public*"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM Cert ARN"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "Deprecated. Custom ALB now always creates and associates a module-managed REGIONAL WAFv2 Web ACL for compliance controls."
  type        = string
  default     = ""
}

variable "waf_log_retention_in_days" {
  description = "Retention in days for the CloudWatch Log Group used by module-created WAF Web ACL logging."
  type        = number
  default     = 365

  validation {
    condition     = var.waf_log_retention_in_days >= 365
    error_message = "waf_log_retention_in_days must be at least 365 days."
  }
}

variable "waf_log_kms_key_id" {
  description = "Optional KMS key ARN for WAF CloudWatch logs encryption. If not set, alias/aws/logs is used."
  type        = string
  default     = ""
}

variable "custom_listener_rules" {
  description = "Custom listener rules from accounts config. Supports source-ip, path-pattern, host-header, http-header, and optional OIDC authentication."
  type = list(object({
    ruleName = string
    priority = number
    conditions = list(object({
      field  = string
      values = optional(list(string), [])
      hostHeaderConfig = optional(object({
        values = list(string)
      }))
      sourceIpConfig = optional(object({
        values = list(string)
      }))
      httpHeaderConfig = optional(object({
        httpHeaderName = string
        values         = list(string)
      }))
    }))
    actions = list(object({
      type            = string
      targetGroupName = optional(string)
      authenticateOidcConfig = optional(object({
        issuer                           = string
        authorizationEndpoint            = string
        tokenEndpoint                    = string
        userInfoEndpoint                 = string
        clientId                         = string
        clientSecret                     = optional(string)
        clientSecretSecretArn            = optional(string)
        clientSecretSecretJsonKey        = optional(string, "client_secret")
        onUnauthenticatedRequest         = optional(string, "authenticate")
        scope                            = optional(string, "openid")
        sessionCookieName                = optional(string, "AWSELBAuthSessionCookie")
        sessionTimeout                   = optional(number, 604800)
        authenticationRequestExtraParams = optional(map(string), {})
      }))
    }))
  }))
  default = []
}
