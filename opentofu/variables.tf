variable "cloudflare_domain_prefix" {
  description = "Domain prefix (without root domain) used to expose instance to the Internet"
  type        = string
  default     = "external"
}

variable "cloudflare_zone_id" {
  description = "Zone ID for domain"
  type        = string
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
