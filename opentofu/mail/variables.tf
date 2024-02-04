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

variable "password_primary" {
  description = "Password for primary account"
  type        = string
  sensitive   = true
}

variable "sender_name" {
  description = "Display name used when sending e-mail"
  type        = string
}
