locals {
  # Subnets advertised by the NAS (tag:router). Keep in sync with TS_ROUTES in
  # docker/tailscale/compose.yaml.
  tailscale_router_routes = ["192.168.42.0/24", "192.168.2.0/24"]
}

# Single-user tailnet: allow-all. Tags only decide device ownership (no key
# expiry for the NAS) and which routes get approved without a console click.
resource "tailscale_acl" "policy" {
  overwrite_existing_content = true

  acl = jsonencode({
    tagOwners = {
      "tag:router" = ["autogroup:admin"]
    }

    grants = [
      {
        src = ["*"]
        dst = ["*"]
        ip  = ["*"]
      },
      {
        src = ["autogroup:member"]
        dst = ["autogroup:internet"]
        ip  = ["*"]
      },
    ]

    autoApprovers = {
      routes   = { for route in local.tailscale_router_routes : route => ["tag:router"] }
      exitNode = ["tag:router"]
    }
  })
}

resource "tailscale_tailnet_settings" "settings" {
  acls_externally_managed_on = true
  acls_external_link         = "https://git.ajgon.casa/deedee/mark13/src/branch/master/opentofu/tailscale.tf"

  # Mutually exclusive with Tailnet Lock, which gates new devices instead.
  devices_approval_on       = false
  devices_auto_updates_on   = true
  devices_key_duration_days = 180

  # Every Pocket-ID user could otherwise join; new users need an explicit approval.
  users_approval_on = true

  # https_enabled / network_flow_logging_on are left at their default (off): they
  # need the extra networking_settings / logs:network OAuth scopes. Keep HTTPS
  # off anyway - `tailscale serve` certs would publish machine names in CT logs.
  posture_identity_collection_on = false
  regional_routing_on            = false
}

resource "tailscale_dns_configuration" "dns" {
  magic_dns          = true
  override_local_dns = false

  split_dns {
    domain = "ajgon.casa"
    nameservers {
      address = "192.168.42.1"
    }
  }

  split_dns {
    domain = "internal"
    nameservers {
      address = "192.168.42.1"
    }
  }
}

# One-shot bootstrap key for the NAS subnet router / exit node. Once used it is
# spent; to re-join the NAS, replace this resource and sign the new key with
# `tailscale lock sign` on a signing node (Tailnet Lock).
resource "tailscale_tailnet_key" "nas" {
  description         = "nas subnet router"
  reusable            = false
  ephemeral           = false
  preauthorized       = true
  tags                = ["tag:router"]
  expiry              = 7 * 24 * 3600
  recreate_if_invalid = "never"

  depends_on = [tailscale_acl.policy]
}

output "tailscale_nas_auth_key" {
  value     = tailscale_tailnet_key.nas.key
  sensitive = true
}
