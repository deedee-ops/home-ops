variable "b2_application_key_id" {
  description = "Backblaze B2 application key ID used by OpenTofu itself. Needs bucket management; this is NOT the key the fleet backs up with."
  type        = string
  sensitive   = true
}

variable "b2_application_key" {
  description = "Backblaze B2 application key used by OpenTofu itself"
  type        = string
  sensitive   = true
}

variable "b2_backup_bucket_name" {
  description = "Bucket holding the offsite kopia repository shared by kopiur and the NAS"
  type        = string
}

variable "b2_backup_retention_days" {
  description = "GOVERNANCE object-lock period, in days, applied to every blob written to the backup bucket"
  type        = number
  default     = 7
}

variable "b2_backup_noncurrent_expiry_days" {
  description = "Days a hidden (non-current) file version survives before B2 deletes it. This is the window in which a plain delete is still reversible."
  type        = number
  default     = 30
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

variable "static_sites" {
  description = "Map of hostname to static HTML served on every path of that hostname. The hostname must belong to one of the zones declared in `domains`."
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
