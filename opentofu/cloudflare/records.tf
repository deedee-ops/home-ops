# Cloudflare Tunnel Ingress
resource "cloudflare_record" "external_ingress" {
  zone_id = data.cloudflare_zone.base_domain.id
  name    = "external"
  content = "${cloudflare_tunnel.homelab.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}
