variable "domain_primary" {
  description = "Primary domain"
  type        = object({ name = string, verification_code = string })
  sensitive   = true
}

variable "domain_spam" {
  description = "Spam domain"
  type        = object({ name = string })
  sensitive   = true
}

variable "domain_aliases" {
  description = "List of aliases for primary domain"
  type        = map(object({ verification_code = string }))
}

variable "extra_identities" {
  description = "List of extra identities allowed to send and receive"
  type = map(object({
    name        = string,
    password    = optional(string),
    may_receive = optional(bool),
    may_send    = optional(bool)
  }))
}

variable "password_primary" {
  description = "Password for primary account"
  type        = string
  sensitive   = true
}

variable "sender_name" {
  description = "Display name used when sending e-mail"
  type        = string
}

variable "spam_senders" {
  description = "List of spammers to reject"
  type        = list(string)
}

variable "spam_targets" {
  description = "List of email addresses targeted by spammers"
  type        = list(string)
}
