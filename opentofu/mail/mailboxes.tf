resource "migadu_mailbox" "igor" {
  name        = var.sender_name
  domain_name = var.domain_primary.name
  local_part  = "igor"
  password    = var.password_primary

  auto_respond_active     = false
  footer_active           = false
  is_internal             = false
  may_access_imap         = true
  may_access_manage_sieve = true
  may_access_pop3         = false
  may_receive             = true
  may_send                = true

  sender_denylist = var.spam_senders
}

resource "migadu_alias" "ajgon" {
  domain_name = var.domain_primary.name
  local_part  = "ajgon"

  destinations = [
    "igor@${var.domain_primary.name}"
  ]
}

resource "migadu_identity" "extra" {
  for_each = var.extra_identities

  domain_name  = var.domain_primary.name
  local_part   = "igor"
  identity     = each.key
  password_use = "none"
  name         = each.value.name

  may_access_imap         = false
  may_access_manage_sieve = false
  may_access_pop3         = false
  may_receive             = true
  may_send                = true
}
