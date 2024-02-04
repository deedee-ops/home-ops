provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "migadu" {
  username = var.mail_migadu_admin_username
  token    = var.mail_migadu_admin_token
  timeout  = 30
  endpoint = "https://api.migadu.com/v1/"
}
