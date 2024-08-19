resource "cloudflare_record" "primary_verify" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "@"
  content = "hosted-email-verify=${var.domain_primary.verification_code}"
  type    = "TXT"
}

resource "cloudflare_record" "primary_mx_primary" {
  zone_id  = data.cloudflare_zone.domain_primary.id
  name     = "@"
  content  = "aspmx1.migadu.com"
  type     = "MX"
  priority = "10"
}

resource "cloudflare_record" "primary_mx_secondary" {
  zone_id  = data.cloudflare_zone.domain_primary.id
  name     = "@"
  content  = "aspmx2.migadu.com"
  type     = "MX"
  priority = "20"
}

resource "cloudflare_record" "primary_mx_dkim_a" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "key1._domainkey"
  content = "key1.${var.domain_primary.name}._domainkey.migadu.com."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "primary_mx_dkim_b" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "key2._domainkey"
  content = "key2.${var.domain_primary.name}._domainkey.migadu.com."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "primary_mx_dkim_c" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "key3._domainkey"
  content = "key3.${var.domain_primary.name}._domainkey.migadu.com."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "primary_spf" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "@"
  content = "v=spf1 include:spf.migadu.com -all"
  type    = "TXT"
}

resource "cloudflare_record" "primary_dmarc" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "_dmarc"
  content = "v=DMARC1; p=quarantine;"
  type    = "TXT"
}

resource "cloudflare_record" "primary_autoconfig" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "autoconfig"
  content = "autoconfig.migadu.com."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "primary_autodiscover" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "_autodiscover._tcp"
  type    = "SRV"

  data {
    service  = "_autodiscover"
    proto    = "_tcp"
    name     = var.domain_primary.name
    priority = 0
    weight   = 1
    port     = 443
    target   = "autodiscover.migadu.com"
  }
}

resource "cloudflare_record" "primary_submissions" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "_submissions._tcp"
  type    = "SRV"

  data {
    service  = "_submissions"
    proto    = "_tcp"
    name     = var.domain_primary.name
    priority = 0
    weight   = 1
    port     = 465
    target   = "smtp.migadu.com"
  }
}

resource "cloudflare_record" "primary_imaps" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "_imaps._tcp"
  type    = "SRV"

  data {
    service  = "_imaps"
    proto    = "_tcp"
    name     = var.domain_primary.name
    priority = 0
    weight   = 1
    port     = 993
    target   = "imap.migadu.com"
  }
}

resource "cloudflare_record" "primary_pop3s" {
  zone_id = data.cloudflare_zone.domain_primary.id
  name    = "_pop3s._tcp"
  type    = "SRV"

  data {
    service  = "_pop3s"
    proto    = "_tcp"
    name     = var.domain_primary.name
    priority = 0
    weight   = 1
    port     = 995
    target   = "pop.migadu.com"
  }
}
