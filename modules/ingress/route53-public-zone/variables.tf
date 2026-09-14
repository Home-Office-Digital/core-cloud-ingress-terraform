variable "tags" {
  type        = map(string)
  description = "Tags to apply to AWS resources"
}

variable "acm_records" {
  type    = list(object({ name = string, type = string, value = string }))
  default = []
}

variable "external_alb_dns" {
  description = "The DNS name of the external ALB"
  type        = string
  default     = ""
}

variable "alb_hosted_zone_id" {
  description = "The DNS ZONE name of the external ALB"
  type        = string
  default     = ""
}

variable "external_ingress" {
  description = "If false, do not create any external ingress resources"
  type        = bool
  default     = false
}
variable "alb_dns_ready" {
  description = "Flag to determine if the ALB Route 53 record should be created"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name for the Route 53 record"
  type        = string
}

variable "additional_domain_names" {
  description = "Additional domain names to create public ALB alias records for (each gets its own *.domain A record)."
  type        = list(string)
  default     = []
}

variable "additional_acm_records" {
  description = "Map of additional domain name => its ACM DNS validation record (name/type/value) to create in that domain's hosted zone."
  type = map(object({
    name  = string
    type  = string
    value = string
  }))
  default = {}
}
