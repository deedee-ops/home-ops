resource "cloudflare_tunnel" "homelab" {
  account_id = var.account_id
  name       = "homelab tunnel"
  secret     = var.tunnel_secret
  config_src = "local"
}
