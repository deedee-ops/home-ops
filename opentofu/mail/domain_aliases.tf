resource "cloudflare_record" "aliases_verify" {
  for_each = data.cloudflare_zone.domain_aliases

  zone_id = each.value.id
  name    = "@"
  value   = "hosted-email-verify=${var.domain_aliases[each.value.name].verification_code}"
  type    = "TXT"
}

resource "cloudflare_record" "aliases_mx_primary" {
  for_each = data.cloudflare_zone.domain_aliases

  zone_id  = each.value.id
  name     = "@"
  value    = "aspmx1.migadu.com"
  type     = "MX"
  priority = "10"
}

resource "cloudflare_record" "aliases_mx_secondary" {
  for_each = data.cloudflare_zone.domain_aliases

  zone_id  = each.value.id
  name     = "@"
  value    = "aspmx2.migadu.com"
  type     = "MX"
  priority = "20"
}

resource "cloudflare_record" "aliases_mx_dkim_a" {
  for_each = data.cloudflare_zone.domain_aliases

  zone_id = each.value.id
  name    = "key1._domainkey"
  value   = "key1.${each.value.name}._domainkey.migadu.com."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "aliases_mx_dkim_b" {
  for_each = data.cloudflare_zone.domain_aliases

  zone_id = each.value.id
  name    = "key2._domainkey"
  value   = "key2.${each.value.name}._domainkey.migadu.com."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "aliases_mx_dkim_c" {
  for_each = data.cloudflare_zone.domain_aliases

  zone_id = each.value.id
  name    = "key3._domainkey"
  value   = "key3.${each.value.name}._domainkey.migadu.com."
  proxied = false
  type    = "CNAME"
}

resource "cloudflare_record" "aliases_spf" {
  for_each = data.cloudflare_zone.domain_aliases

  zone_id = each.value.id
  name    = "@"
  value   = "v=spf1 include:spf.migadu.com -all"
  type    = "TXT"
}

resource "cloudflare_record" "aliases_dmarc" {
  for_each = data.cloudflare_zone.domain_aliases

  zone_id = each.value.id
  name    = "_dmarc"
  value   = "v=DMARC1; p=quarantine;"
  type    = "TXT"
}
