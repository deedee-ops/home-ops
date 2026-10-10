locals {
  # Subnets advertised by the NAS (tag:router). Keep in sync with TS_ROUTES in
  # docker/tailscale/compose.yaml.
  tailscale_router_routes = ["192.168.42.0/24", "192.168.2.0/24"]

  # envoy-external LoadBalancer IP. Keep in sync with LB_EXTERNAL_IP in
  # kubernetes/clusters/deedee/apps/network/envoy-gateway.yaml.
  tailscale_edge_ingress = "192.168.42.31"
}

# Members (me) get everything. Tagged devices get only what they need:
# - tag:router (NAS) - subnet router + exit node; initiates nothing but arcane.
# - tag:edge (mandark) - internet facing, so treat as hostile: it can reach
#   envoy-external:443 and nothing else on the LAN or the tailnet.
resource "tailscale_acl" "policy" {
  overwrite_existing_content = true

  acl = jsonencode({
    # tag:provisioner is the only tag on the opentofu OAuth client. A client can mint
    # keys only for exactly its own tag set, or for tags owned by those tags - so every
    # node tag is owned by tag:provisioner, and new tags need no console change.
    # Nothing ever runs as tag:provisioner; it grants no network access.
    tagOwners = {
      "tag:provisioner" = ["autogroup:admin"]
      "tag:router"      = ["autogroup:admin", "tag:provisioner"]
      "tag:edge"        = ["autogroup:admin", "tag:provisioner"]
    }

    grants = [
      {
        src = ["autogroup:member"]
        dst = ["*"]
        ip  = ["*"]
      },
      {
        src = ["autogroup:member"]
        dst = ["autogroup:internet"]
        ip  = ["*"]
      },
      # Public ingress: traefik-vps passes TLS through to envoy-external.
      {
        src = ["tag:edge"]
        dst = [local.tailscale_edge_ingress]
        ip  = ["tcp:443"]
      },
      # Arcane manager (NAS) -> arcane-agent on mandark, exposed via `tailscale serve`.
      {
        src = ["tag:router"]
        dst = ["tag:edge"]
        ip  = ["tcp:3553"]
      },
      # mandark is a peer relay: roaming devices and the NAS are both behind
      # NAT (home is CGNAT), so without it they fall back to DERP.
      {
        src = ["autogroup:member", "tag:router"]
        dst = ["tag:edge"]
        app = {
          "tailscale.com/cap/relay" = []
        }
      },
    ]

    # Evaluated on every policy update - the apply fails if edge access widens.
    tests = [
      {
        src    = "tag:edge"
        accept = ["${local.tailscale_edge_ingress}:443"]
        deny = [
          "${local.tailscale_edge_ingress}:80",
          "192.168.42.1:22",
          "192.168.42.1:53",
          "192.168.2.1:443",
          "tag:router:22",
        ]
      },
      {
        src    = "tag:router"
        accept = ["tag:edge:3553"]
        deny   = ["tag:edge:22", "${local.tailscale_edge_ingress}:443"]
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

# Node bootstrap keys - one per tagged node, tagged, preauthorized, single-use.
#
# Tailnet Lock is on (signing nodes: liadtop, work). It is deliberately out of
# reach of the API, so it is not managed here: it was enabled once with
# `tailscale lock init` on a signing node. A node joining with an unsigned key
# stays locked out until signed, so every key below is signed *before* use, on
# a signing node, and the signed key it prints is what goes to the node:
#
#   tofu output -raw tailscale_<node>_auth_key | xargs tailscale lock sign
#
# Once used, a key is spent and the node identity lives in its state dir. Keys
# also expire 7 days after creation. To (re)join a node - rebuild, lost state,
# expired key - mint a fresh one and sign it again:
#
#   tofu apply -replace=tailscale_tailnet_key.<node>
#
# NAS subnet router / exit node: the signed key is TS_AUTHKEY in docker/tailscale.
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

# mandark edge: the signed key is vault_tailscale_auth_key in the ansible vault.
resource "tailscale_tailnet_key" "mandark" {
  description         = "mandark edge"
  reusable            = false
  ephemeral           = false
  preauthorized       = true
  tags                = ["tag:edge"]
  expiry              = 7 * 24 * 3600
  recreate_if_invalid = "never"

  depends_on = [tailscale_acl.policy]
}

output "tailscale_mandark_auth_key" {
  value     = tailscale_tailnet_key.mandark.key
  sensitive = true
}
