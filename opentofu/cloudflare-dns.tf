resource "cloudflare_dns_record" "dns_extra_record" {
  for_each = {
    for record in local.extra_dns_records : record.key => record
  }

  zone_id = var.domains[each.value.domain_name].zone_id
  name    = each.value.record_name
  type    = each.value.record_type
  content = each.value.record_content
  proxied = each.value.record_proxied
  ttl     = 1
}
