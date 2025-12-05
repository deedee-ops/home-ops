terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.13.0"
    }

    migadu = {
      source  = "metio/migadu"
      version = "2025.12.4"
    }
  }
  required_version = ">= 1.6.0"

  backend "local" {
    path = "terraform.tfstate"
  }

  encryption {
    key_provider "pbkdf2" "tofu_state_password" {
      passphrase = var.tofu_state_password
    }

    method "aes_gcm" "tofu_state_password" {
      keys = key_provider.pbkdf2.tofu_state_password
    }

    state {
      method   = method.aes_gcm.tofu_state_password
      enforced = true
    }
  }
}
