terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.15.0"
    }

    migadu = {
      source  = "metio/migadu"
      version = "2025.12.11"
    }
  }
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket = "states"
    key    = "opentofu/terraform.tfstate"
    region = "us-east-1"

    skip_credentials_validation = true
    skip_region_validation      = true
    use_path_style              = true

    endpoints = {
      s3 = "https://s3.ajgon.casa"
    }
  }
}
