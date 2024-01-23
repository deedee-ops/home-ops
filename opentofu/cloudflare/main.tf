terraform {
  backend "s3" {
    bucket = "deedee"
    key    = "opentofu/terraform.tfstate"

    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }

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
