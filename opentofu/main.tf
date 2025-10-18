terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.11.0"
    }

    migadu = {
      source  = "metio/migadu"
      version = "2025.6.19"
    }
  }
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket                      = "states"
    endpoint                    = "https://s3.rzegocki.dev"
    key                         = "opentofu/k8s/terraform.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    use_path_style              = true
  }
}
