resource "cloudflare_dns_record" "migadu_dns_verify" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = "@"
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
  name     = "@"
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
  name     = "@"
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
  name    = "key1._domainkey"
  content = "key1.${each.key}._domainkey.migadu.com."
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
  name    = "key2._domainkey"
  content = "key2.${each.key}._domainkey.migadu.com."
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
  name    = "key3._domainkey"
  content = "key3.${each.key}._domainkey.migadu.com."
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
  name    = "@"
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
  name    = "_dmarc"
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
  name    = "autoconfig"
  content = "autoconfig.migadu.com."
  proxied = false
  type    = "CNAME"
  ttl     = 1
}

resource "cloudflare_dns_record" "migadu_dns_autodiscover" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if !opts.spam && !(opts.alias == null ? true : opts.alias) && opts.migadu_verification_code != null
  }

  zone_id = var.domains[each.key].zone_id
  name    = "_autodiscover._tcp"
  type    = "SRV"
  ttl     = 1

  data = {
    service  = "_autodiscover"
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

  zone_id = var.domains[each.key].zone_id
  name    = "_submissions._tcp"
  type    = "SRV"
  ttl     = 1

  data = {
    service  = "_submissions"
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

  zone_id = var.domains[each.key].zone_id
  name    = "_imaps._tcp"
  type    = "SRV"
  ttl     = 1

  data = {
    service  = "_imaps"
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

  zone_id = var.domains[each.key].zone_id
  name    = "_pop3s._tcp"
  type    = "SRV"
  ttl     = 1

  data = {
    service  = "_pop3s"
    proto    = "_tcp"
    name     = each.key
    priority = 0
    weight   = 1
    port     = 995
    target   = "pop.migadu.com"
  }
}
