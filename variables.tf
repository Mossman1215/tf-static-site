variable "website_domain_main" {
  description = "Main website domain, e.g. example.com"
  type        = string
}

variable "website_domain_aliases" {
  description = "Alternative domains for the same site, e.g. www.example.com"
  default     = null
  type        = list(string)
}

variable "dynamic_paths" {
  description = "url paths that route to dynamic_endpoint"
  default     = null
  type        = list(string)
}

variable "acm_arn_validated" {
  description = "certificate resource to be provided when dns validation has completed"
  default     = null
  type        = string
}

variable "dynamic_endpoint" {
  description = "load balancer or other cloudfront compatible endpoint that recieves requests from dynamic_paths"
  type        = string
}

variable "project" {
  type = string
}