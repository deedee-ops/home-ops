resource "cloudflare_dns_record" "migadu_dns_verify" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = each.key
  content = "hosted-email-verify=${each.value.migadu_verification_code}"
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_dns_record" "migadu_dns_mx_primary" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id  = var.domains[each.key].zone_id
  name     = each.key
  content  = "aspmx1.migadu.com"
  type     = "MX"
  priority = "10"
  ttl      = 1
}

resource "cloudflare_dns_record" "migadu_dns_mx_secondary" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id  = var.domains[each.key].zone_id
  name     = each.key
  content  = "aspmx2.migadu.com"
  type     = "MX"
  priority = "20"
  ttl      = 1
}

resource "cloudflare_dns_record" "migadu_dns_mx_dkim_a" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = "key1._domainkey.${each.key}"
  content = "key1.${each.key}._domainkey.migadu.com"
  proxied = false
  type    = "CNAME"
  ttl     = 1
}

resource "cloudflare_dns_record" "migadu_dns_mx_dkim_b" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = "key2._domainkey.${each.key}"
  content = "key2.${each.key}._domainkey.migadu.com"
  proxied = false
  type    = "CNAME"
  ttl     = 1
}

resource "cloudflare_dns_record" "migadu_dns_mx_dkim_c" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = "key3._domainkey.${each.key}"
  content = "key3.${each.key}._domainkey.migadu.com"
  proxied = false
  type    = "CNAME"
  ttl     = 1
}

resource "cloudflare_dns_record" "migadu_dns_spf" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = each.key
  content = "v=spf1 include:spf.migadu.com -all"
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_dns_record" "migadu_dns_dmarc" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = "_dmarc.${each.key}"
  content = "v=DMARC1; p=quarantine;"
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_dns_record" "migadu_dns_autoconfig" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && !(opts.alias == null ? true : opts.alias) && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = "autoconfig.${each.key}"
  content = "autoconfig.migadu.com"
  proxied = false
  type    = "CNAME"
  ttl     = 1
}

resource "cloudflare_dns_record" "migadu_dns_autodiscover" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && !(opts.alias == null ? true : opts.alias) && opts.migadu_verification_code != null
  }

  zone_id  = var.domains[each.key].zone_id
  name     = "_autodiscover._tcp.${each.key}"
  type     = "SRV"
  priority = 0
  ttl      = 1

  data = {
    proto    = "_tcp"
    name     = each.key
    priority = 0
    weight   = 1
    port     = 443
    target   = "autodiscover.migadu.com"
  }
}

resource "cloudflare_dns_record" "migadu_dns_submissions" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && !(opts.alias == null ? true : opts.alias) && opts.migadu_verification_code != null
  }

  zone_id  = var.domains[each.key].zone_id
  name     = "_submissions._tcp.${each.key}"
  priority = 0
  type     = "SRV"
  ttl      = 1

  data = {
    proto    = "_tcp"
    name     = each.key
    priority = 0
    weight   = 1
    port     = 465
    target   = "smtp.migadu.com"
  }
}

resource "cloudflare_dns_record" "migadu_dns_imaps" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && !(opts.alias == null ? true : opts.alias) && opts.migadu_verification_code != null
  }

  zone_id  = var.domains[each.key].zone_id
  name     = "_imaps._tcp.${each.key}"
  type     = "SRV"
  priority = 0
  ttl      = 1

  data = {
    proto    = "_tcp"
    name     = each.key
    priority = 0
    weight   = 1
    port     = 993
    target   = "imap.migadu.com"
  }
}

resource "cloudflare_dns_record" "migadu_dns_pop3s" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && !(opts.alias == null ? true : opts.alias) && opts.migadu_verification_code != null
  }

  zone_id  = var.domains[each.key].zone_id
  name     = "_pop3s._tcp.${each.key}"
  type     = "SRV"
  priority = 0
  ttl      = 1

  data = {
    proto    = "_tcp"
    name     = each.key
    priority = 0
    weight   = 1
    port     = 995
    target   = "pop.migadu.com"
  }
}
