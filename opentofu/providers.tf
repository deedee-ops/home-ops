provider "cloudflare" {
  api_token = var.cloudflare_token
}

provider "migadu" {
  username = var.migadu_username
  token    = var.migadu_token
  timeout  = 30
  endpoint = "https://api.migadu.com/v1/"
}
