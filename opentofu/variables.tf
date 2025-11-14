variable "tofu_state_password" {
  description = "Decryption password for tofu state"
  type        = string
  sensitive   = true
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

variable "cloudflare_domain_prefix" {
  description = "Domain prefix (without root domain) used to expose instance to the Internet"
  type        = string
  default     = "external"
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
      from       = optional(string)
      expression = optional(string)
      to         = string
      permament  = bool
    })))
  }))
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
