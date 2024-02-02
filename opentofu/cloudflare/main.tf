terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.23.0"
    }
  }

  required_version = ">= 1.6.0"
}

data "cloudflare_zone" "base_domain" {
  name = var.base_domain
}
