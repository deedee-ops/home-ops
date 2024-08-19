resource "cloudflare_record" "spam_mx_primary" {
  zone_id  = data.cloudflare_zone.domain_spam.id
  name     = "@"
  content  = "mail.anonaddy.me."
  type     = "MX"
  priority = "10"
}

resource "cloudflare_record" "spam_mx_secondary" {
  zone_id  = data.cloudflare_zone.domain_spam.id
  name     = "@"
  content  = "mail2.anonaddy.me."
  type     = "MX"
  priority = "20"
}

resource "cloudflare_record" "spam_mx_dkim_a" {
  zone_id = data.cloudflare_zone.domain_spam.id
  name    = "dk1._domainkey"
  content = "dk1._domainkey.anonaddy.me."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "spam_mx_dkim_b" {
  zone_id = data.cloudflare_zone.domain_spam.id
  name    = "dk2._domainkey"
  content = "dk2._domainkey.anonaddy.me."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "spam_spf" {
  zone_id = data.cloudflare_zone.domain_spam.id
  name    = "@"
  content = "v=spf1 include:spf.anonaddy.me -all"
  type    = "TXT"
}

resource "cloudflare_record" "spam_dmarc" {
  zone_id = data.cloudflare_zone.domain_spam.id
  name    = "_dmarc"
  content = "v=DMARC1; p=quarantine; adkim=s"
  type    = "TXT"
}
