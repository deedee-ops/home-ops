# Creates a new remotely-managed tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "k8s_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "k8s tunnel"
}

# Reads the token used to run the tunnel on the server.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "k8s_tunnel_token" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.id
}

# Creates the CNAME record that routes http_app.${var.cloudflare_domain} to the tunnel.
resource "cloudflare_dns_record" "external_ingress" {
  for_each = {
    for name, opts in var.domains : name => opts
    if(opts.tunneled == null ? false : opts.tunneled)
  }

  zone_id = each.value.zone_id
  name    = var.cloudflare_domain_prefix
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

output "cloudflare_tunnel_token" {
  value     = data.cloudflare_zero_trust_tunnel_cloudflared_token.k8s_tunnel_token
  sensitive = true
}
