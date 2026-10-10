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

variable "migadu_username" {
  description = "Migadu API user"
  type        = string
  sensitive   = true
}

variable "migadu_token" {
  description = "Migadu API user token"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID (scopes: policy_file, dns, feature_settings, auth_keys with tag:provisioner)"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  sensitive   = true
}

variable "domains" {
  description = "List of domains and their zone configuration options"
  type = map(object({
    zone_id = string
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
      from          = optional(string)
      expression    = optional(string)
      to            = optional(string)
      to_expression = optional(string)
      permament     = bool
    })))
  }))
}

variable "static_sites" {
  description = "Map of hostname to static HTML served on every path of that hostname. The hostname must belong to one of the zones declared in `domains`."
  type        = map(string)
  default     = {}
}

variable "webfinger" {
  description = "Map of domain to OIDC issuer URL advertised via WebFinger (/.well-known/webfinger) for acct:*@<domain>. The domain must be one of the zones declared in `domains`."
  type        = map(string)
  default     = {}
}

variable "mailboxes" {
  description = "List of migadu mailboxes, and attached aliases and identities"
  type = map(map(object({
    sender_name         = string
    password            = string
    spam_aggressiveness = optional(string)
    spam_action         = optional(string)
    sender_allowlist    = optional(list(string))
    sender_denylist     = optional(list(string))
    recipient_denylist  = optional(list(string))
    aliases             = optional(list(string))
    identities = optional(map(object({
      sender_name     = string
      password        = optional(string)
      may_receive     = bool
      may_send        = bool
      may_access_imap = optional(bool)
    })))
  })))
}
