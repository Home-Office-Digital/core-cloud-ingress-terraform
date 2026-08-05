variable "acceptance_required" {
  description = "Whether or not VPC endpoint connection requests to the service must be accepted by the service owner - true or false."
  type        = bool
  default     = true
}

variable "allowed_principals" {
  description = "The ARNs of one or more principals allowed to discover the endpoint service."
  type        = set(string)
  default     = []
}

variable "network_load_balancer_arns" {
  description = "Amazon Resource Names (ARNs) of one or more Network Load Balancers for the endpoint service."
  type        = set(string)
}

variable "principal_arns" {
  description = "The ARN of the principals allowed to discover the VPC endpoint service."
  type        = set(string)
  default     = []
}

variable "private_dns_name" {
  description = "The private DNS name for the service."
  type        = string
  default     = null
}

variable "private_dns_verification" {
  description = "Begins the verification process. The service provider should add a record to the DNS server before setting this to true."
  type        = bool
  default     = false
}
