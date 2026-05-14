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

variable "custom_listener_rules" {
  description = "Listener rules for custom ingress profile. Supports host/path/source-ip/http-header conditions and optional OIDC auth."
  type = list(object({
    name              = string
    priority          = number
    target_group_type = optional(string, "http2")
    host_headers      = optional(list(string), [])
    path_patterns     = optional(list(string), [])
    source_ips        = optional(list(string), [])
    http_header_conditions = optional(list(object({
      name   = string
      values = list(string)
    })), [])
    oidc = optional(object({
      authorization_endpoint              = string
      client_id                           = string
      client_secret                       = optional(string)
      client_secret_secret_arn            = optional(string)
      client_secret_secret_json_key       = optional(string, "client_secret")
      issuer                              = string
      token_endpoint                      = string
      user_info_endpoint                  = string
      on_unauthenticated_request          = optional(string, "authenticate")
      scope                               = optional(string, "openid")
      session_cookie_name                 = optional(string, "AWSELBAuthSessionCookie")
      session_timeout                     = optional(number, 604800)
      authentication_request_extra_params = optional(map(string), {})
    }))
  }))
  default = []
}
