variable "base_domain" {
  description = "Domain used for all homelab needs"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_secret" {
  description = "Cloudflare tunnel secret (at least 32 bytes, base64 encoded)"
  type        = string
  sensitive   = true
}
