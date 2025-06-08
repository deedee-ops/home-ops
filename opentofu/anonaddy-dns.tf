resource "cloudflare_dns_record" "anonaddy_mx_primary" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if opts.spam
  }

  zone_id  = var.domains[each.key].zone_id
  name     = each.key
  content  = "mail.anonaddy.me"
  type     = "MX"
  priority = "10"
  ttl      = 1
}

resource "cloudflare_dns_record" "anonaddy_mx_secondary" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if opts.spam
  }

  zone_id  = var.domains[each.key].zone_id
  name     = each.key
  content  = "mail2.anonaddy.me"
  type     = "MX"
  priority = "20"
  ttl      = 1
}

resource "cloudflare_dns_record" "anonaddy_mx_dkim_a" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if opts.spam
  }

  zone_id = var.domains[each.key].zone_id
  name    = "dk1._domainkey.${each.key}"
  content = "dk1._domainkey.anonaddy.me"
  proxied = false
  type    = "CNAME"
  ttl     = 1
}

resource "cloudflare_dns_record" "anonaddy_mx_dkim_b" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if opts.spam
  }

  zone_id = var.domains[each.key].zone_id
  name    = "dk2._domainkey.${each.key}"
  content = "dk2._domainkey.anonaddy.me"
  proxied = false
  type    = "CNAME"
  ttl     = 1
}

resource "cloudflare_dns_record" "anonaddy_spf" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if opts.spam
  }

  zone_id = var.domains[each.key].zone_id
  name    = each.key
  content = "v=spf1 include:spf.anonaddy.me -all"
  type    = "TXT"
  ttl     = 1
}

resource "cloudflare_dns_record" "anonaddy_dmarc" {
  for_each = {
    for name, opts in local.mail_domains : name => opts
    if opts.spam
  }

  zone_id = var.domains[each.key].zone_id
  name    = "_dmarc.${each.key}"
  content = "v=DMARC1; p=quarantine; adkim=s"
  type    = "TXT"
  ttl     = 1
}
