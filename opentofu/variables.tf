variable "cloudflare_domain_prefix" {
  description = "Domain prefix (without root domain) used to expose instance to the Internet"
  type        = string
  default     = "external"
}

variable "cloudflare_account_id" {
  description = "Account ID for Cloudflare account"
  type        = string
  sensitive   = true
}

variable "cloudflare_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "domains" {
  description = "List of domains and their zone configuration options"
  type = map(object({
    zone_id  = string
    tunneled = optional(bool)
    mail = optional(object({
      spam                     = bool,
      alias                    = optional(bool),
      migadu_verification_code = optional(string)
    }))
    records = optional(map(object({
      type    = string
      content = string
      proxied = optional(bool)
    })))
    redirects = optional(map(object({
      from      = string
      to        = string
      permament = bool
    })))
  }))
}
