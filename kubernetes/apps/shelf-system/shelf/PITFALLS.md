# Shelf.nu deployment — pitfalls, rationale & non-obvious config

Everything here was discovered the hard way while self-hosting **Shelf.nu**
(AGPL, `ghcr.io/shelf-nu/shelf.nu`) against a **trimmed Supabase** stack, wired
to **Pocket-ID** for OIDC. Read this before touching the manifests — most of the
env values look arbitrary but each one fixes a specific failure.

## Source references (pinned commits — `file:line` refs below are relative to these)

Links point at the exact commit read, so line numbers stay valid. `supabase/auth`
and `supabase/storage` are pinned to the **release tags matching the deployed
image versions** (`helmrelease.yaml`); `Shelf-nu/shelf.nu` tracks `:latest`, so
it's pinned to the `main` commit read during this work.

| Component | Version / image | Reference commit |
| --------- | --------------- | ---------------- |
| GoTrue (`supabase/auth`) | `v2.193.1` | [`6b7b8e6`](https://github.com/supabase/auth/tree/6b7b8e6033c988905fa56e5534b0112ad193aba3) |
| storage-api (`supabase/storage`) | `v1.67.13` | [`67a3fc6`](https://github.com/supabase/storage/tree/67a3fc6195cb04bc7322bfb5fee07fdae3555bb2) |
| Shelf (`Shelf-nu/shelf.nu`) | `:latest` (main) | [`b5c36a8`](https://github.com/Shelf-nu/shelf.nu/tree/b5c36a862078830d1eb3ffc4272dcea1a4752bd9) |
| `rs/cors` (bundled by GoTrue) | `v1.11.0` | [`4c32059`](https://github.com/rs/cors/tree/4c32059b2756926619f6bf70281b91be7b5dddb2) |
| `gobuffalo/pop` (bundled by GoTrue) | `v6.1.1` | [`71505e8`](https://github.com/gobuffalo/pop/tree/71505e87de051f45b7097ee8b0f6127d6686d441) |

Key files referenced below (deep-links to the pinned commits):

<!-- markdownlint-disable MD013 -->
- GoTrue: [`internal/api/external.go`](https://github.com/supabase/auth/blob/6b7b8e6033c988905fa56e5534b0112ad193aba3/internal/api/external.go) ·
  [`internal/api/provider/keycloak.go`](https://github.com/supabase/auth/blob/6b7b8e6033c988905fa56e5534b0112ad193aba3/internal/api/provider/keycloak.go) ·
  [`internal/utilities/url_validator.go`](https://github.com/supabase/auth/blob/6b7b8e6033c988905fa56e5534b0112ad193aba3/internal/utilities/url_validator.go) ·
  [`internal/storage/dial.go`](https://github.com/supabase/auth/blob/6b7b8e6033c988905fa56e5534b0112ad193aba3/internal/storage/dial.go) ·
  [`hack/init_postgres.sql`](https://github.com/supabase/auth/blob/6b7b8e6033c988905fa56e5534b0112ad193aba3/hack/init_postgres.sql) ·
  [`internal/api/api.go`](https://github.com/supabase/auth/blob/6b7b8e6033c988905fa56e5534b0112ad193aba3/internal/api/api.go)
- storage-api: [`src/config.ts`](https://github.com/supabase/storage/blob/67a3fc6195cb04bc7322bfb5fee07fdae3555bb2/src/config.ts) ·
  [`src/internal/database/pg-connection.ts`](https://github.com/supabase/storage/blob/67a3fc6195cb04bc7322bfb5fee07fdae3555bb2/src/internal/database/pg-connection.ts)
- Shelf: [`apps/webapp/app/modules/user/service.server.ts`](https://github.com/Shelf-nu/shelf.nu/blob/b5c36a862078830d1eb3ffc4272dcea1a4752bd9/apps/webapp/app/modules/user/service.server.ts) ·
  [`apps/webapp/app/routes/_auth+/oauth.callback.tsx`](https://github.com/Shelf-nu/shelf.nu/blob/b5c36a862078830d1eb3ffc4272dcea1a4752bd9/apps/webapp/app/routes/_auth+/oauth.callback.tsx) ·
  [`apps/webapp/app/utils/auth.ts`](https://github.com/Shelf-nu/shelf.nu/blob/b5c36a862078830d1eb3ffc4272dcea1a4752bd9/apps/webapp/app/utils/auth.ts) ·
  [`apps/webapp/app/utils/subscription.server.ts`](https://github.com/Shelf-nu/shelf.nu/blob/b5c36a862078830d1eb3ffc4272dcea1a4752bd9/apps/webapp/app/utils/subscription.server.ts)
<!-- markdownlint-enable MD013 -->

---

## 1. Why this architecture at all

- **Shelf is hard-coupled to Supabase**, not just Postgres. Verified in source:
  it uses Prisma for the DB **and** `getSupabaseAdmin().auth.admin.*` (GoTrue)
  for every auth op **and** `.storage.from(bucket)` (storage-api) for every
  image. Plain Postgres is *not* enough — GoTrue and storage-api must run too.
- We run the **minimum** Supabase: Postgres + GoTrue + storage-api. Dropped
  Kong, Studio, Realtime, PostgREST, imgproxy.
- **No Kong**: its only job is path-routing `/auth/v1/*`→GoTrue and
  `/storage/v1/*`→storage-api. Replaced by the `supabase` HTTPRoute with
  `URLRewrite` (ReplacePrefixMatch `/`). The anon/service keys are JWTs that
  GoTrue/storage verify themselves, so Kong's apikey handling isn't needed.
- **No Redis / Dragonfly**: none of Shelf, GoTrue, or storage-api use Redis
  (checked deps). storage-api sets its own per-connection search_path and has no
  cache dependency.
- **Two hostnames**: `shelf.$ROOT_DOMAIN` (the app/PWA) and
  `shelf-supabase.$ROOT_DOMAIN` (the Supabase gateway). Shelf's client builds
  `${SUPABASE_URL}/auth/v1/...` and `/storage/v1/...`, and public asset URLs live
  under it, so it must be its own host.

---

## 2. Database wiring

### 2.1 DB URL is composed at runtime, not from the CNPG `uri` key

The CNPG `-app` secret's `uri`/`dbname` point at the cluster's **default** `app`
database, but our tables live in the **`shelf`** database (created by the
`Database` CR). So every container builds its own URL from the discrete
`PG*` env (`shelf-db-app` host/port/username/password) in a `/bin/sh -c`
wrapper, hardcoding `/shelf` — the same pattern as `ai/honcho`. Do **not**
switch these to the `uri` key; you'll silently connect to the wrong database.

### 2.2 Supabase roles + schemas must be pre-created (`_postgresql.yaml`)

GoTrue and storage-api assume a Supabase-shaped Postgres. `postInitApplicationSQL`
(runs once, as superuser, at initdb) creates:

- roles `anon`, `authenticated`, `service_role`, `authenticator`,
  `supabase_auth_admin`, `supabase_storage_admin`, granted to `app`.
- schemas `auth` and `storage` **`AUTHORIZATION app`**. GoTrue creates *tables*
  in `auth` but never the schema itself; without it, GoTrue crashes on migration
  00 with `schema "auth" does not exist`.
- extensions `pgcrypto`, `uuid-ossp`, `pg_trgm` (via the `Database` CR).

`postInitApplicationSQL` only runs on a **fresh** cluster. On an already-created
DB you must run the role/schema SQL by hand.

### 2.3 GoTrue runtime search_path — the `?search_path=auth` on its URL

GoTrue migrations qualify DDL with the namespace (`auth.flow_state` etc.), but
its **runtime** `pop` queries are *unqualified* and rely on the connecting
role's default search_path being `auth` (upstream `hack/init_postgres.sql`:
`ALTER USER supabase_auth_admin SET search_path = 'auth'`). `dial.go` does **not**
derive search_path from `GOTRUE_DB_NAMESPACE` (that only qualifies migrations).
We connect as the shared `app` role (search_path `public`), so runtime queries
failed with `relation "flow_state" does not exist`.
Fix: append `?search_path=auth` to `GOTRUE_DB_DATABASE_URL`. `pop` forwards the
URL query into the DSN and lib/pq passes `search_path` as a backend runtime
param — scoped to GoTrue's connections only. `GOTRUE_DB_NAMESPACE=auth` is still
needed for the migration DDL qualification.

- **storage-api** is unaffected: it sets its own per-connection search_path
  (`['storage','public','extensions']`) in `pg-connection.ts`.
- **Shelf/Prisma** is unaffected: Prisma fully schema-qualifies.

### 2.4 Toggling search_path moved GoTrue's migration-tracking table

`pop` keeps its `schema_migrations` tracker in the first schema on the path.
Runs before `?search_path=auth` recorded it in `public.schema_migrations`;
after, `pop` looked at (empty) `auth.schema_migrations` and replayed all
migrations over a half-populated `auth`, dying on `oauth_clients`
(`column "client_id" does not exist` — a later migration deliberately drops
`client_id`). Fix on the live DB was `DROP SCHEMA auth CASCADE; CREATE SCHEMA
auth AUTHORIZATION app;` then let GoTrue migrate fresh. Only relevant if you
flip search_path on an existing install.

---

## 3. Storage-api (file backend)

- `STORAGE_S3_BUCKET: shelf` — **required even for the `file` backend.** The path
  is `FILE_STORAGE_BACKEND_PATH/STORAGE_S3_BUCKET/...`; without it the TUS init
  `mkdir`s `/var/lib/storage/undefined` and the process aborts.
- `FILE_STORAGE_BACKEND_PATH: /var/lib/storage` — the volsync-backed PVC mount.
- `DB_INSTALL_ROLES: "false"` — roles are pre-created by initdb (§2.2).
- `POSTGREST_URL: ""` — we don't run PostgREST; storage-api talks to Postgres
  directly.
- `TENANT_ID` / `REGION` — arbitrary single-tenant identifiers.

### 3.1 PVC ext4 corruption (one-off, not systemic)

The first `shelf` RBD volume came up with a corrupt ext4 **root directory**
(`talosctl dmesg`: `EXT4-fs error … inode #2 … No space for directory leaf
checksum`), so every `mkdir` returned `EBADMSG (-74)`. This was a **fluke** on a
volsync-provisioned RBD — ~30 other volsync/`ceph-block` volumes are healthy.
Fix was wipe + recreate the PVC (`ceph-block` RWO, single writer — CephFS/RWX is
**not** needed). Not a Caddy/libuv/io_uring issue (those were red herrings).

---

## 4. Shelf webapp

- **The published image does NOT run migrations** (entrypoint is just
  `node build/server/index.js`) and the `prisma` CLI is pruned out of the prod
  image. The `01-db-migrate` init container runs
  `npx --yes prisma migrate deploy` (hence the npm/prisma FQDNs in the
  NetworkPolicy). If you'd rather not pull from npm at boot, prebuild a migration
  image.
- `ENABLE_PREMIUM_FEATURES: "false"` — every tier check is
  `if (!premiumIsEnabled) return true` (`subscription.server.ts`), so self-hosting
  gets **everything** unlocked (unlimited custom fields, bookings, import/export,
  audits, barcodes). This is the whole point; do not set it true.
- `DISABLE_SSO: "false"` — the OIDC `/oauth/callback` **403s** if SSO is disabled.
- `DISABLE_SIGNUP: "false"` — **critical & counter-intuitive.** This gates
  whether the OIDC callback provisions a user *and their personal workspace*
  (`createUser`: `shouldCreatePersonalOrg = !config.disableSignup`). Set to
  `true` and login succeeds but the user has no organization ("You do not have
  access to any organization"). Self-serve email signup is already off via
  `GOTRUE_EXTERNAL_EMAIL_ENABLED=false`; access is gated by Pocket-ID.
- **Required-at-boot env even in OIDC-only mode** (Shelf validates these in
  `env.ts`/`instrument.server.js` and crashes if unset):
  - `MAPTILER_TOKEN` — non-empty. `"unused"` boots fine; maps just won't render.
    Swap for a real MapTiler token to get the location map.
  - `SMTP_HOST` — non-empty. `SMTP_PWD`/`SMTP_USER` may be empty. No mail is sent
    with OIDC-only single-user; point at a real relay for invites/notifications.
- `NODE_EXTRA_CA_CERTS: /certs/homelab.pem` — server-side calls to `SUPABASE_URL`
  hairpin through the internal gateway (homelab-CA cert). Node **appends** this
  to its trust store.

---

## 5. OIDC — the hard part

Goal: log in via **Pocket-ID** (OIDC-only) with **no Shelf fork**.

### 5.1 Shelf has no OIDC — only email/OTP + SAML SSO

So we drive login through GoTrue's OAuth machinery and reuse Shelf's existing
`/oauth/callback` (which auto-provisions a personal workspace, per
`sso.server.ts`). Login is initiated by an authorize URL, set in two places:

- the `/sso-login` HTTPRoute redirect (repurposes Shelf's SAML page), and
- the `PocketIDOIDCClient.launchUrl`.

### 5.2 `scopes=openid` goes in the authorize URL, NOT an env

GoTrue reads provider scopes from the `/authorize` **query param**
(`external.go:43: scopes := query.Get("scopes")`). There is **no**
`GOTRUE_EXTERNAL_*_SCOPES` env. The keycloak provider hardcodes `[profile,email]`
and *appends* whatever arrives in `scopes`. Pocket-ID (strict OIDC) rejects any
request without `openid` → "something went wrong". Hence
`?provider=keycloak&scopes=openid` in both authorize URLs.

### 5.3 Why the `keycloak` provider + a Caddy shim (and NOT a custom provider)

- GoTrue's built-in **`keycloak` provider hardcodes** the Keycloak URL paths:
  `/protocol/openid-connect/{auth,token,userinfo}`. Pocket-ID serves **none** of
  them — its real endpoints (from its discovery doc) are `/authorize`,
  `/api/oidc/token`, `/api/oidc/userinfo`. All Keycloak paths just return
  Pocket-ID's SPA shell (HTTP 200), so the browser lands on an unrouted page →
  "something went wrong".
- GoTrue's **custom (discovery-based) OIDC provider** would read Pocket-ID's real
  endpoints automatically — **but** its create/discovery has a hardcoded **SSRF
  guard** (`internal/utilities/url_validator.go`) that rejects any issuer
  resolving to a **private IP (RFC 1918)** with `400 URL cannot resolve to
  private network addresses`. `id.$ROOT_DOMAIN` is an internal LB → blocked, and
  there is **no config to disable it**. (Custom providers also require a
  `custom:` identifier prefix and are DB-stored via `POST /admin/custom-providers`
  — stateful, lost on any auth-schema reset.) Dead end.
- **Solution:** keep the built-in keycloak provider (built-ins skip the SSRF
  check — they don't do discovery) and point `GOTRUE_EXTERNAL_KEYCLOAK_URL` at an
  in-namespace **Caddy shim** (`oidc-shim`, host `shelf-oidc.$ROOT_DOMAIN`,
  `resources/Caddyfile`) that translates the paths:
  - `/protocol/openid-connect/auth` → **302** to `id/authorize` (must be a
    redirect, not a rewrite — the browser URL has to change so Pocket-ID's SPA
    routes it, and the user stays on `id.$ROOT_DOMAIN` for its session cookie).
    Envoy/Caddy preserve the query string.
  - `/protocol/openid-connect/token` → reverse_proxy `id/api/oidc/token`
  - `/protocol/openid-connect/userinfo` → reverse_proxy `id/api/oidc/userinfo`
  - `header_up Host id.$ROOT_DOMAIN` + `tls_trusted_ca_certs /certs/homelab.pem`
    for the upstream TLS.
  This keeps everything in `shelf-system` and does **not** touch the shared
  Pocket-ID route.

### 5.4 `GOTRUE_EXTERNAL_KEYCLOAK_REDIRECT_URI` is set explicitly

GoTrue derives an external provider's redirect as `API_EXTERNAL_URL + "/callback"`
(`external.go:693`). `API_EXTERNAL_URL` is `https://shelf-supabase.$ROOT_DOMAIN`
(no `/auth/v1`), which would give the wrong, unrouted `…/callback`. The keycloak
provider lets us override it directly, so we pin
`GOTRUE_EXTERNAL_KEYCLOAK_REDIRECT_URI=https://shelf-supabase.$ROOT_DOMAIN/auth/v1/callback`
— matching both the `supabase` route and the `PocketIDOIDCClient.callbackUrls`.
(This is *why* we could revert `API_EXTERNAL_URL` after abandoning the custom
provider, which had no redirect override.)

### 5.5 `SSL_CERT_FILE: /certs/homelab.pem` (GoTrue is Go)

GoTrue reaches the shim (and Pocket-ID via the shim) over TLS with homelab-CA
certs. **Caveat:** in Go, `SSL_CERT_FILE` *replaces* the system CA pool (it does
not append). That's fine here because GoTrue only talks to homelab-CA hosts +
Postgres. If GoTrue ever needs a public-CA endpoint, this must change.

### 5.6 `oidc-shim` (Caddy) needs `NET_BIND_SERVICE`

The official Caddy binary carries a `cap_net_bind_service` file capability. Under
`allowPrivilegeEscalation: false` (NoNewPrivs) + `drop: [ALL]`, the kernel
refuses to exec it (`operation not permitted`). Adding back `NET_BIND_SERVICE`
(the only cap restricted-PSA allows) makes the fscap non-escalating and it runs.
`Unconfined` seccomp is not an option under restricted PSA.

### 5.7 Claim mapping: Pocket-ID must emit `firstname` / `lastname`

Shelf's callback reads `user_metadata.custom_claims.firstname` /
`.lastname` (`app/utils/auth.ts`; also accepts `firstName`/`lastName`). GoTrue's
keycloak provider copies **every non-standard claim** (all except
`name`/`sub`/`email`/`email_verified`) into `custom_claims`. The standard OIDC
`given_name`/`family_name` are **not** read by Shelf. So add custom claims named
exactly `firstname` and `lastname` to the user/group in Pocket-ID, or the
callback errors "First name is required".

---

## 6. CORS — `GOTRUE_CORS_ALLOWED_HEADERS: "*"`

Shelf's browser JS calls `${SUPABASE_URL}/auth/v1/user` cross-origin with an
`apikey` header. GoTrue's default CORS allow-list omits `apikey` (Kong normally
handles it), so the preflight dropped `Access-Control-Allow-Origin` and the
browser hung on "connecting your account". Enumerating headers is **not** enough:
GoTrue bundles **rs/cors v1.11.0**, which matches multi-header preflights with a
sorted-set `Subsumes()` (cors.go:368) that rejects the browser's header order
unless `allowedHeadersAll` is set. Single-header requests pass; real (multi-
header) preflights fail. `"*"` sets `allowedHeadersAll` and short-circuits the
check.

---

## 7. `/sso-login` redirect + query-string quirk

The `route.app` `/sso-login` rule is a Gateway API `RequestRedirect` with
`ReplaceFullPath` containing an embedded query
(`…/authorize?provider=keycloak&scopes=openid&redirect_to=…`). Envoy passes the
query through **unencoded** (verified) — `:` and `/` are legal in a query value,
matching `PocketIDOIDCClient.launchUrl`. This shadows Shelf's built-in SAML
`/sso-login` page and is the SP-initiated OIDC entry point.

---

## 8. User provisioning — the `sso` flag

Even with a personal workspace created, an OIDC user lands on
`/sso-pending-assignment` ("No workspace assigned"). Cause: `createUser` sets
`User.sso = true` for anyone coming through the SSO callback, and
`oauth.callback.tsx:147` hides the personal workspace for SSO users
(`isSSO && !hasTeamOrgs → redirect`), expecting an admin/SCIM to assign them to a
**team** org. `updateUserFromSSO` does **not** rewrite `sso` on later logins, so
the fix sticks:

```sql
UPDATE public."User" SET sso = false WHERE email = '<email>';
```

This is **systemic** — every new OIDC user gets `sso=true` and needs the flip
(no env toggle exists). Alternative: create a shared **team** org and assign
users via `UserOrganization` (then `hasTeamOrgs=true`).

---

## 9. One-time / manual operations (not in Git)

| When | SQL / action | Why |
| ---- | ------------ | --- |
| Existing cluster (initdb already ran) | the role + `CREATE SCHEMA auth/storage` from §2.2 | `postInitApplicationSQL` won't re-run |
| After flipping search_path on a live DB | `DROP SCHEMA auth CASCADE; CREATE SCHEMA auth AUTHORIZATION app;` restart GoTrue | migration-tracker moved schemas (§2.4) |
| Each new OIDC user | `UPDATE public."User" SET sso = false WHERE email = …` | escape `/sso-pending-assignment` (§8) |
| Re-provision an org-less user | `DELETE FROM public."User" WHERE email = …` then re-login | lets `createUser` rebuild the workspace |
| openbao `kubernetes/shelf-system/shelf` | `SESSION_SECRET`, `INVITE_TOKEN_SECRET`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY` | ANON/SERVICE are JWTs signed with JWT_SECRET (role anon/service_role) |
| Pocket-ID | add `firstname` / `lastname` custom claims | Shelf callback needs them (§5.7) |

---

## 10. Assumptions worth revisiting

- **Cert for `shelf-oidc.$ROOT_DOMAIN`** relies on the same wildcard/cert-manager
  path as the other `*.$ROOT_DOMAIN` hosts.
- **Shelf image pinned by digest** but there's no semver tag stream — Renovate
  can't bump it cleanly.
- **`npx prisma migrate deploy` at init** pulls from npm on every webapp start
  (allowed in the NetworkPolicy). Consider a prebuilt migration image.
- Custom-provider registration (`register-oidc` job) and the API_EXTERNAL_URL
  `/auth/v1` variant were **abandoned** — don't reintroduce them; they hit the
  SSRF wall (§5.3).
