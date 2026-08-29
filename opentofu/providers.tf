provider "b2" {
  application_key_id = var.b2_application_key_id
  application_key    = var.b2_application_key
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

provider "migadu" {
  username = var.migadu_username
  token    = var.migadu_token
  timeout  = 30
  endpoint = "https://api.migadu.com/v1/"
}
