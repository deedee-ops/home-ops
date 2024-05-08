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
      version = "4.32.0"
    }

    migadu = {
      source  = "metio/migadu"
      version = "2024.5.2"
    }
  }

  required_version = ">= 1.6.0"
}

module "cloudflare" {
  account_id    = var.cloudflare_account_id
  base_domain   = var.base_domain
  tunnel_secret = var.cloudflare_tunnel_secret

  source = "./cloudflare"
  providers = {
    cloudflare = cloudflare
  }
}

module "mail" {
  domain_primary   = var.mail_domain_primary
  domain_spam      = var.mail_domain_spam
  domain_aliases   = var.mail_domain_aliases
  extra_identities = var.mail_extra_identities
  password_primary = var.mail_password_primary
  sender_name      = var.mail_sender_name
  spam_senders     = var.mail_spam_senders
  spam_targets     = var.mail_spam_targets

  source = "./mail"
  providers = {
    cloudflare = cloudflare
    migadu     = migadu
  }
}
