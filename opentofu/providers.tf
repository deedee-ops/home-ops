provider "cloudflare" {
  api_token = var.cloudflare_token
}

provider "migadu" {
  username = var.migadu_username
  token    = var.migadu_token
  timeout  = 30
  endpoint = "https://api.migadu.com/v1/"
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
}
