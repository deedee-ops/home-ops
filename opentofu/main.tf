terraform {
  backend "s3" {
    bucket = "deedee"
    key    = "opentofu/terraform.tfstate"

    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.23.0"
    }
  }

  required_version = ">= 1.6.0"
}

module "cloudflare" {
  account_id = var.cloudflare_account_id
  base_domain = var.base_domain
  tunnel_secret = var.cloudflare_tunnel_secret

  source = "./cloudflare"
  providers = {
    cloudflare = cloudflare
  }
}
