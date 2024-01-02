resource "cloudflare_tunnel" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "homelab tunnel"
  secret     = var.cloudflare_tunnel_secret
  config_src = "local"
}
