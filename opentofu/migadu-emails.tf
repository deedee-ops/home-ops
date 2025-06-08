resource "migadu_mailbox" "mailboxes" {
  for_each = {
    for mailbox in local.mail_mailboxes : mailbox.key => mailbox
  }

  name        = each.value.sender_name
  domain_name = each.value.domain_name
  local_part  = each.value.local_part
  password    = each.value.password

  auto_respond_active     = false
  footer_active           = false
  is_internal             = false
  may_access_imap         = true
  may_access_manage_sieve = true
  may_access_pop3         = false
  may_receive             = true
  may_send                = true

  spam_aggressiveness = each.value.spam_aggressiveness
  spam_action         = each.value.spam_action
  sender_allowlist    = each.value.sender_allowlist
  sender_denylist     = each.value.sender_denylist
  recipient_denylist  = each.value.recipient_denylist
}

resource "migadu_alias" "aliases" {
  for_each = {
    for alias in local.mail_aliases : alias.key => alias
  }

  domain_name = each.value.domain_name
  local_part  = each.value.alias_local_part

  destinations = [
    "${each.value.mailbox_local_part}@${each.value.domain_name}"
  ]
}

resource "migadu_identity" "identities" {
  for_each = {
    for identity in local.mail_identities : identity.key => identity
  }

  domain_name  = each.value.domain_name
  local_part   = each.value.mailbox_local_part
  identity     = each.value.identity_local_part
  password_use = each.value.password_use
  password     = each.value.password
  name         = each.value.sender_name

  may_receive             = each.value.may_receive
  may_send                = each.value.may_send
  may_access_imap         = each.value.may_access_imap
  may_access_pop3         = false
  may_access_manage_sieve = false
}
