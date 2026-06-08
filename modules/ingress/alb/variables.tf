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

variable "entra_only_access" {
  description = "When true, restricts ALB ingress to Entra IP ranges via prefix list instead of open internet"
  type        = bool
  default     = false
}

variable "entra_prefix_list_ids" {
  description = "Prefix list IDs to allow when entra_only_access is true — e.g. the managed prefix lists from the entra-prefix-list-sync Lambda"
  type        = list(string)
  default     = []
}