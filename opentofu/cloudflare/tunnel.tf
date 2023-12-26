resource "cloudflare_tunnel" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "homelab tunnel"
  secret     = var.cloudflare_tunnel_secret
  config_src = "local"
}

#resource "cloudflare_tunnel_config" "homelab" {
  #account_id = var.cloudflare_account_id
  #tunnel_id = cloudflare_tunnel.homelab.id

  #config {
    #ingress_rule {
      #service = "http_status:404"
    #}
  #}
#}
