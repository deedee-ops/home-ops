locals {
  extra_dns_records = flatten([
    for domain_name, domain_opts in var.domains : [
      for record_name, record_opts in(domain_opts.records == null ? {} : domain_opts.records) : {
        key            = "${domain_name}_${record_name}"
        domain_name    = domain_name
        record_name    = record_name
        record_type    = record_opts.type
        record_content = record_opts.content
        record_proxied = (record_opts.proxied == null ? false : record_opts.proxied)
      }
    ]
  ])

  mail_domains = {
    for domain_name, domain_opts in var.domains : domain_name => (domain_opts.mail == null ? {
      spam                     = false
      migadu_verification_code = null
      alias                    = null
    } : domain_opts.mail)
  }

  mail_aliases = flatten([
    for domain_name, domain_mailboxes in var.mailboxes : [
      for local_part, mailbox_opts in domain_mailboxes : [
        for alias in(mailbox_opts.aliases == null ? [] : mailbox_opts.aliases) : {
          key                = "${domain_name}_${local_part}_${alias}"
          domain_name        = domain_name
          mailbox_local_part = local_part
          alias_local_part   = alias
        }
      ]
    ]
  ])

  mail_identities = flatten([
    for domain_name, domain_mailboxes in var.mailboxes : [
      for local_part, mailbox_opts in domain_mailboxes : [
        for identity_name, identity_opts in(mailbox_opts.identities == null ? {} : mailbox_opts.identities) : {
          key                 = "${domain_name}_${local_part}_${identity_name}"
          domain_name         = domain_name
          mailbox_local_part  = local_part
          identity_local_part = identity_name
          sender_name         = identity_opts.sender_name
          password_use        = identity_opts.password == null ? "none" : "custom"
          password            = identity_opts.password
          may_receive         = identity_opts.may_receive
          may_send            = identity_opts.may_send
          may_access_imap     = identity_opts.may_access_imap == null ? false : identity_opts.may_access_imap
        }
      ]
    ]
  ])

  mail_mailboxes = flatten([
    for domain_name, domain_mailboxes in var.mailboxes : [
      for local_part, mailbox_opts in domain_mailboxes : {
        key                 = "${domain_name}_${local_part}"
        domain_name         = domain_name
        local_part          = local_part
        sender_name         = mailbox_opts.sender_name
        password            = mailbox_opts.password
        spam_aggressiveness = mailbox_opts.spam_aggressiveness == null ? "default" : mailbox_opts.spam_aggressiveness
        spam_action         = mailbox_opts.spam_action == null ? "folder" : mailbox_opts.spam_action
        sender_allowlist    = mailbox_opts.sender_allowlist == null ? [] : mailbox_opts.sender_allowlist
        sender_denylist     = mailbox_opts.sender_denylist == null ? [] : mailbox_opts.sender_denylist
        recipient_denylist  = mailbox_opts.recipient_denylist == null ? [] : mailbox_opts.recipient_denylist
      }
    ]
  ])

  redirects = flatten([
    for domain_name, domain_opts in var.domains : [
      for redirect_name, redirect_opts in(domain_opts.redirects == null ? {} : domain_opts.redirects) : {
        key                 = "${domain_name}_${redirect_name}"
        domain_name         = domain_name
        redirect_name       = redirect_name
        redirect_expression = redirect_opts.from == null ? redirect_opts.expression : "(http.request.full_uri wildcard \"${redirect_opts.from}\")"
        redirect_to         = redirect_opts.to
        redirect_permament  = redirect_opts.permament
      }
    ]
  ])
}
