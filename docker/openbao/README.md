# OpenBao

## Unseal

`openbao-unsealer` checks the seal status every 5 seconds and unseals OpenBao whenever it is sealed, including after
a NAS reboot. To keep OpenBao sealed on purpose, stop it first:

```bash
docker stop openbao-unsealer
bao operator seal # needs a token with sudo on sys/seal
```

`restart: unless-stopped` keeps it stopped, also across reboots, until the next `docker compose up` of this stack.

## OIDC

```bash
bao auth enable oidc
bao auth tune -listing-visibility=unauth oidc

bao write auth/oidc/config \
  oidc_discovery_url="https://id.ajgon.casa" \
  oidc_client_id="<client id>" \
  oidc_client_secret="<client secret>" \
  default_role="oidc-default"
bao write auth/oidc/role/oidc-default \
  bound_audiences="<client id>" \
  allowed_redirect_uris="https://bao.ajgon.casa/ui/vault/auth/oidc/oidc/callback" \
  allowed_redirect_uris="https://bao.ajgon.casa/oidc/oidc/callback" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  user_claim="email" \
  groups_claim="groups" \
  token_policies="default" \
  oidc_scopes="openid profile email groups"

bao policy write admin - << EOF
path "*" {
  capabilities = ["sudo","read","create","update","delete","list","patch"]
}
EOF

bao write identity/group name="oidc-admins" policies="admin" type="external"
# note the id

bao auth list
# note accessor

bao write identity/group-alias name="admins" mount_accessor="<noted accessor>" canonical_id="<noted id>"
```

## Metrics

```bash
bao policy write metrics - << EOF
path "/sys/metrics" {
  capabilities = ["read"]
}
EOF
bao token create -orphan -ttl=87600h -policy=metrics
```
