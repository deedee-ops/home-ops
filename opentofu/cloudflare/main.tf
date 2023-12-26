terraform {
  cloud {
    organization = "deedee-ops"
    hostname = "app.terraform.io"

    workspaces {
      name = "home-ops"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.20.0"
    }
  }

  required_version = ">= 1.6.0"
}

data "cloudflare_zone" "base_domain" {
  name = var.base_domain
}
