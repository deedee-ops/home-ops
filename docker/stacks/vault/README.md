# Vault

## Configuring OIDC

```bash
vault auth enable oidc
vault auth tune -listing-visibility=unauth oidc

vault write auth/oidc/config \
  oidc_discovery_url="https://id.<root domain>" \
  oidc_client_id="<client id>" \
  oidc_client_secret="<client secret>" \
  default_role="oidc-default"
vault write auth/oidc/role/oidc-default \
  bound_audiences="<client id>" \
  allowed_redirect_uris="https://vault.<root domain>/ui/vault/auth/oidc/oidc/callback" \
  allowed_redirect_uris="https://vault.<root domain>/oidc/oidc/callback" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  user_claim="email" \
  groups_claim="groups" \
  token_policies="default" \
  oidc_scopes="openid profile email groups"

tee admin.json <<EOF
path "*" {
  capabilities = ["sudo","read","create","update","delete","list","patch"]
}
EOF
vault policy write admin admin.json

vault write identity/group name="oidc-admins" policies="admin" type="external"
# note the id

vault auth list
# note accessor

vault write identity/group-alias name="admins" mount_accessor="<noted accessor>" canonical_id="<noted id>"
```
