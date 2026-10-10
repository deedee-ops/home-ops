# DR-PLAN: air-gapped disaster recovery (agent notes)

Audience: Claude only. Terse by design. Verify every "FACT" again before acting (written 2026-10-10, may be stale).

## 0. Goal / scope

- GOAL: rebuild whole homelab (NAS + k8s cluster `deedee`) from scratch with zero or minimal internet.
- ASSUME: all backups survive: borg (`/mnt/fast/docker`, `/mnt/fast/backups`, tank), kopiur PVC backups, garage data
  (`DATA_S3_DIR`), zot dirs (`${DATA_DOCKER_DIR}/zot/*`), openbao data.
- NON-GOAL: keeping a running cluster alive during an internet outage (different problem; see 9.DROPPED).
- STATUS: nothing below implemented yet. User said "not today". Ask user which tasks to do before starting.

## 1. Current state (FACTS, verified 2026-10-10)

### 1.1 zot (done, committed in 3e06d881)

- `docker/zot/compose.yaml`: services `zot-secrets` (alpine init), `zot-registry`, `zot-cache`; shared `x-zot` anchor.
- image `ghcr.io/project-zot/zot:v2.1.22@sha256:96cda114...`; binary is `/usr/local/bin/zot-linux-amd64`
  (published image != repo Dockerfile; no HEALTHCHECK in image -> set in compose). Config must be `.yaml` ext.
- `zot-registry`: `registry.${ROOT_DOMAIN}` via traefik; OIDC (Pocket ID, client in
  `kubernetes/apps/security/pocket-id-operator/pocketidoidcclient.yaml` name `zot`), apikey=true, anonymous read,
  group `admins` = rw. S3 bucket `zot` rootdir `/registry`. retention: deleteUntagged, NO keepTags.
- `zot-cache`: NAS port `5010`, anonymous, no auth. S3 bucket `zot` rootdir `/cache`. on-demand sync, 7 upstreams,
  `content: prefix "**" destination /<host>`. `http.compat: [docker2s2]` required. `sync.downloadDir: /var/tmp/zot`.
- cache retention (current): keepTags `mostRecentlyPulledCount: 1`; keepUntagged `mostRecentlyPulledCount: 1` +
  `pulledWithin: 168h`; gc 24h; delay 24h.
- dedupe=true + remoteCache=false => local boltdb `cache.db` maps S3 zero-byte placeholders -> real blobs
  (zot `pkg/storage/imagestore/imagestore.go:2061-2076`). LOSING cache.db BREAKS DEDUPED BLOBS. Must be in backup.
- `${DATA_DOCKER_DIR}/zot/{registry,cache,secret}` are backed up; `cache-downloads` should have `.nobackup`.
- Talos mirrors (`talos/deedee/machineconfig.yaml.j2` ~L293-360): 7x `RegistryMirrorConfig`
  `url: http://nas.internal:5010/v2/<host>`, `overridePath: true`, `skipFallback: true`.
- talos-factory pushes to `zot-registry:5000` using `DOCKER_CONFIG=/docker` written by `talos-factory-secrets`
  (env `REGISTRY_USERNAME`, `REGISTRY_API_KEY`). Core artifacts still pulled direct from ghcr.io (user decision,
  see 8.D2).
- Old `docker/registry`, `docker/registry-cache` removed from repo. Garage buckets `registry`, `cache` may still exist
  (user handles cleanup; do not touch).

### 1.2 zot behaviour notes (source-verified, zot v2.1.22, clone at /tmp/zotsrc may be gone)

- tag GET with on-demand sync: always contacts upstream first unless `manifestCheckInterval`; on sync error falls back
  to local copy (`pkg/api/routes.go:2893-2965`). Digest GET: local first, sync only on miss.
- `/v2/<repo>/tags/list` = LOCAL ONLY, never upstream (`routes.go` ListTags ~L384). Anything that discovers versions by
  listing tags through the cache only sees cached tags.
- on-demand sync stores digest-pinned pulls UNTAGGED (containerd sends digest only for `tag@sha256`).
- on-demand = sparse index: index root + only requested children. Pre-warm must request platform child
  (e.g. `crane manifest --platform linux/amd64`), not just index.
- periodic sync requires BOTH `pollInterval` and non-empty `content` (`pkg/extensions/extension_sync.go:48`).
- retention: rules OR'ed; empty patterns = all tags; no keepTags => keep all tags; untagged w/o stats => kept.
  metaDB pull stats only exist when retention/search/auth enabled.
- legacy cosign `.sig` tags re-sync every periodic pass (bug: compares tag-name digest vs sig digest). Harmless noise.
- docker hub upstream: `https://registry-1.docker.io`; containerd adds `library/` itself.
- KNOWN ISSUE K1 (observed 2026-10-10 15:00Z): COLD PULL TIMEOUT. On-demand sync is synchronous: zot answers the child
  manifest GET only after the full image is downloaded to `downloadDir` AND pushed to S3. Large images exceed
  containerd "timeout awaiting response headers" -> `ErrImagePull` (DeadlineExceeded).
  - example: `ghcr.io/bjw-s-labs/forgejo-runner:ubuntu-24.04@sha256:8b7a25c7...` (amd64 child `sha256:4978da80...`):
    download 15:00:29->15:00:52, S3 push ->15:02:11 (~1m40s); node pulls failed 15:00:59 / 15:01:01; forgejo runner
    task pods deleted by runner (jobs failed).
  - self-heals: sync completes in background, next pull served from cache. `skipFallback: true` => no upstream
    fallback. Small images stay under timeout.
  - regression vs old distribution proxy (it streamed blobs while caching).
  - NOT fixable via Talos (containerd response-header timeout not exposed in RegistryMirrorConfig).
  - `onDemandInBackground: true` only turns timeout into fast 404 -> same retry outcome; not a fix.
  - mitigation: pre-warm (T7). If insufficient: investigate S3 push speed to garage (the slower half: ~80s vs ~23s
    download) — zot/garage upload chunking, dedupe overhead.
  - DR impact HIGH: fresh cluster => every pull goes through zot; any image missing from cache = guaranteed first-pull
    failure + backoff. Also measure serving latency of cached images at bootstrap scale (T9).

### 1.3 Inventory (snapshot 2026-10-10; regenerate before implementing)

- running cluster images: 164 distinct. by registry: ghcr.io 85, quay.io 22, registry.k8s.io 18, docker.io 21
  (12 explicit + 9 implicit), registry.ajgon.casa 9, mirror.gcr.io 2, gsoci.azurecr.io 1, + UNMIRRORED below.
- UNMIRRORED cluster registries (pull direct -> fail offline; `skipFallback` irrelevant, no mirror at all):

| registry | used by |
| --- | --- |
| code.forgejo.org | forgejo-system/forgejo |
| data.forgejo.org | forgejo-system/runner |
| registry.erwanleboucher.dev | forgejo-system/runner (runner-k8s-plugin) |
| git.ow-ops.eu | network/towonel-agent |
| public.ecr.aws | default/garmin (influxdb 1.x) |
| nixery.dev | media/jellyfin init (`shell/xmlstarlet:latest`) |

- repos with >1 version running simultaneously: `registry.k8s.io/sig-storage/csi-resizer`,
  `registry.k8s.io/sig-storage/csi-node-driver-registrar`, `docker.io/library/caddy` -> current retention
  (keep 1) will evict one of each after 7d unless re-pulled.
- Flux: 102 HelmReleases, ALL via `OCIRepository` (205 files match `kind: OCIRepository`). URLs by host:
  ghcr.io 95, quay.io 3, code.forgejo.org 1, codeberg.org 1, gsoci.azurecr.io 1, mirror.gcr.io 1.
  No HelmRepository, no Bucket. Flux source-controller pulls directly (containerd mirrors DO NOT apply).
- Flux GitRepository: `https://github.com/deedee-ops/home-ops` (only one).
- FluxInstance: `distribution.artifact: oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests:v0.61.0`,
  `distribution.registry: ghcr.io/fluxcd`. source-controller storage = emptyDir.
- bootstrap charts (`bootstrap/helmfile.d/00-crds.yaml`, `01-apps.yaml`), all direct OCI:
  envoy-gateway (mirror.gcr.io), external-secrets, grafana-operator, kopiur, kube-prometheus-stack, coredns, spegel,
  flux-operator, flux-instance (ghcr.io), silence-operator (gsoci.azurecr.io), trust-manager, cilium, cert-manager
  (quay.io). Flow: `bootstrap/mod.just` -> talos apply -> talosctl bootstrap -> resources.yaml.j2 -> helmfile crds
  (template|apply) -> helmfile apps (sync).
- secrets: ClusterSecretStore `openbao` (vault provider, `https://bao.ajgon.casa`, on NAS) => local. bootstrap
  `resources.yaml.j2` needs `VAULT_TOKEN`.
- ClusterIssuers: `openbao` (local vault), `letsencrypt-production` (ACME, internet). LE used by
  `kubernetes/apps/network/envoy-gateway/certificate.yaml` (+ clusterissuer file).
- Talos boot: matchbox profile -> `docker/matchbox/config/assets/talos-nuc-12.ipxe` L39
  `kernel https://talos.ajgon.casa/pxe/<schematic>/v1.14.2/metal-amd64-secureboot` (FACTORY DEPENDENCY).
  installer: machineconfig L246 `talos.ajgon.casa/installer-secureboot/<schematic>:v1.14.2` (FACTORY DEPENDENCY).
  schematic `3158c22eb3c614983204dc3033adff59b8e0de7cafc71c9d7aca10f69f84e43c`. alpine debug entry uses
  dl-cdn.alpinelinux.org (ignore, debug only).
- zot-registry already holds `talos/images/installer-secureboot/<schematic>:<ver>`, `talos/images/metal-installer/...`,
  `talos/cache`, `talos/schematic` (synced from old registry).
- talos-factory (`ghcr.io/siderolabs/image-factory:v1.7.2`): discovers Talos versions by LISTING TAGS of
  `siderolabs/imager` (`internal/artifacts/versions.go:35`). Unknown: does it serve cached PXE/installer offline
  when version listing fails? -> must test (task T6).
- tuppr (system-upgrade) uses factory installer refs.
- NAS compose images (non-zot, non-garage): ghcr.io (borgmatic, arcane agent, ncps, openbao, image-factory,
  docker-socket-proxy, traefik-to-unifi, wg-easy), docker.io implicit (alpine, garage-ui, ftpserver,
  rustdesk-server, ps3netsrv), quay.io (matchbox, node-exporter, smartctl-exporter), public.ecr.aws (traefik),
  codeberg.org (towonel-agent/node), registry.gitlab.com (tftpd), registry.${ROOT_DOMAIN} (cameras, roms-server).
- NAS docker daemon: `Mirrors: null`, insecure CIDRs `127.0.0.0/8`, `::1/128` => `localhost:5010` works over http
  with NO daemon change. Only docker.io supports daemon `registry-mirrors`.
- Some `docker/*` stacks run on VPS, not NAS (likely `traefik-vps`, `towonel-hub`, maybe `wg-easy`,
  `arcane-agent`?). UNKNOWN -> ask user before rewriting.
- Renovate: `.renovate/homeOpsBase.json5` has `registryAliases: {"mirror.gcr.io": "docker.io"}` and customManager
  regex `oci://(?<depName>[^:]+):(?<currentValue>\S+)`. flux/kubernetes managers scan `*.yaml(.j2)`.
- borgmatic (`docker/borgmatic/config/homelab.yaml`): sources `/mnt/fast/backups`, `/mnt/fast/docker`;
  `exclude_if_present: .nobackup`; repos on BorgBase (EU+US) = INTERNET to restore.

## 2. Target DR bootstrap chain

```text
S1 NAS OS install (TrueNAS media)                         [internet or local ISO]
S2 restore borg -> /mnt/fast/docker (zot, openbao, garage meta...), garage data
S3 docker load bootstrap images (garage, zot, alpine)     [T1]
S4 start garage -> zot (registry+cache)                   [no internet]
S5 start remaining NAS stacks via localhost:5010          [T2]
S6 openbao unseal, traefik-nas, matchbox, talos-factory
S7 PXE boot nodes: kernel from matchbox static assets     [T6]
S8 talos apply; installer from registry.ajgon.casa        [T6]; core images via mirrors [T3]
S9 bootstrap helmfile charts via zot-cache                [T4a]
S10 flux-instance: manifests artifact via zot-cache       [T4c]; sync source = local OCI artifact [T5]
S11 flux apps: charts via zot-cache [T4b], images via mirrors [T3], kopiur restores PVCs (mover images cached [T7])
```

## 3. Tasks

Format: ID | priority | deps | what | how | acceptance | risks.

### T1 bootstrap image archives (MUST)

- deps: none.
- what: offline copies of images that cannot come from zot-cache: zot, garage (+ alpine used by `*-secrets` inits;
  consider docker-socket-proxy/arcane if needed to deploy stacks).
- how: scheduled job / borgmatic `before_backup` hook on NAS: `docker save <img@digest> | zstd > /mnt/fast/backups/
  bootstrap-images/<name>.tar.zst`; keep only current digests (read from `docker/zot/compose.yaml`,
  `docker/garage/compose.yaml`). Runbook: `docker load`. Or: put archives next to repo clone.
- accept: archives exist, refreshed after image bumps, restore tested with `docker load` on a clean host.
- risks: docker socket access needed (socket-proxy is read-only for me; job must run on NAS with rw socket).

### T2 NAS compose images through zot-cache (MUST)

- deps: T1 (zot/garage excluded), add upstream `registry.gitlab.com` (+ `public.ecr.aws`, `codeberg.org` exists) to
  `docker/zot/config/cache.yaml`.
- what: rewrite `image:` in NAS stacks to `localhost:5010/<host>/<repo>...`; implicit docker.io ->
  `localhost:5010/docker.io/library/<x>` or `.../docker.io/<ns>/<x>`.
- exclude: `docker/zot`, `docker/garage`, VPS stacks (ASK user which), images from `registry.${ROOT_DOMAIN}` (local).
- renovate: add `registryAliases` `"localhost:5010/ghcr.io": "ghcr.io"` etc. per host. VERIFY docker-compose manager
  honours registryAliases with path prefix (renovate docs) before mass rewrite; test with `renovate --dry-run` or
  local config validator if possible.
- accept: `docker compose pull` on NAS hits zot-cache (zot-cache logs show sync), renovate still proposes updates.
- risks: if zot-cache down, NAS stack updates fail (accepted). Arcane deploy flow unknown (manager location?).

### T3 mirrors for unmirrored cluster registries (MUST)

- deps: none.
- what: add to `cache.yaml` sync registries + `talos/deedee/machineconfig.yaml.j2` RegistryMirrorConfig for:
  code.forgejo.org, data.forgejo.org, registry.erwanleboucher.dev, git.ow-ops.eu, public.ecr.aws, nixery.dev
  (+ registry.gitlab.com for T2). Same pattern: `destination: /<host>`, `url: http://nas.internal:5010/v2/<host>`,
  `overridePath: true`, `skipFallback: true`.
- check: each upstream supports anonymous pull + docker2s2; nixery builds on demand (`latest` tag, mutable).
- accept: `zot verify` ok; on a node `crictl pull <img>` succeeds and zot-cache logs show sync for new host.
- risks: skipFallback=true => if a new upstream misbehaves through zot, pulls fail with no fallback. Roll out
  one node first.

### T4 charts + flux artifacts through zot-cache (MUST)

- T4a bootstrap: `bootstrap/helmfile.d/*.yaml` `chart: oci://<host>/...` -> `oci://nas.internal:5010/<host>/...`;
  helmfile/helm needs plain-http: helm `--plain-http` (helm >=3.13) via helmfile `args`/repository settings. VERIFY.
- T4b apps: all `OCIRepository.spec.url` -> `oci://nas.internal:5010/<host>/...` + `spec.insecure: true`.
  Mechanical rewrite of ~102 files (generate list via `rg -l "kind: OCIRepository"`). Consider a Flux Kustomization
  patch instead? (JSON6902 cannot regex-rewrite URLs; per-file edit is the realistic path.)
- T4c FluxInstance: `distribution.artifact` -> cache URL. Check flux-operator supports insecure/plain-http artifact
  pulls (option? annotation?). VERIFY in flux-operator docs/source. `distribution.registry: ghcr.io/fluxcd` = image
  prefix -> handled by containerd mirrors, leave.
- renovate: extend customManager regex to strip cache prefix, e.g.
  `oci://(?:nas\.internal:5010/)?(?<depName>[^:]+):(?<currentValue>\S+)`; flux manager handles OCIRepository
  natively -> needs registryAliases `"nas.internal:5010/ghcr.io": "ghcr.io"` etc. VERIFY flux manager honours aliases.
- cosign/`spec.verify`: currently 0 OCIRepositories use verify (checked) -> no issue.
- accept: all OCIRepositories Ready with cache URLs; renovate dashboard still lists chart updates.
- note: Flux polls each OCIRepository every interval -> keeps chart pull stats fresh (good for retention).

### T5 local git source for Flux (MUST for full air-gap)

- option A (runbook only, preferred first): at DR time from local clone:
  `flux push artifact oci://registry.ajgon.casa/home-ops:<sha> --path=./kubernetes --source=... --revision=...`
  then point flux-instance sync (`bootstrap/helmfile.d/templates/flux-values.yaml.gotmpl`) to kind OCIRepository.
  Needs API key (zot-registry auth for push).
- option B (permanent): CI (forgejo/github action) pushes artifact on every commit; flux-instance switchable via var.
- check: how flux-instance `sync` is templated today (read flux-values.yaml.gotmpl), kustomization paths under
  `kubernetes/clusters/<cluster>`.
- accept: cluster reconciles from OCI artifact with github.com unreachable.

### T6 Talos boot without talos-factory (MUST)

- what:
  - PXE: download current secure-boot PXE assets (UKI/kernel+initramfs for schematic `3158c22e...` v1.14.2) into
    matchbox assets (backed up); change `talos-nuc-12.ipxe` L39 to `https://matchbox.ajgon.casa/assets/...`.
    Check secureboot chain: what exactly `/pxe/.../metal-amd64-secureboot` returns (UKI? ipxe script?).
  - installer: machineconfig L246 -> `registry.ajgon.casa/talos/images/installer-secureboot/<schematic>:v1.14.2`
    (exists in zot-registry, anonymous read). Check tuppr TalosUpgrade CRs reference same path pattern.
  - renovate: `.renovate/talosFactory.json5` tracks factory refs -> update rules for new path. READ it first.
- alt: test whether factory serves cached assets offline (block egress) — if yes, keep factory, skip rewrite.
- accept: node PXE boots + installs with talos-factory stopped.
- risks: version bumps now need assets refresh step (automate: renovate post-upgrade or just recipe).

### T7 cache warming CronJob (MUST; raised from SHOULD due to K1)

- why MUST: K1 (cold pull timeout) breaks first pull of every large uncached image, today and in DR.
- also warm on change: run warm for new refs right after renovate bumps merge (e.g. CronJob more often, or
  Flux-notification/webhook trigger) so new versions are cached before kubelet pulls them.

- what: daily in-cluster CronJob: collect image refs from Deployments/StatefulSets/DaemonSets/CronJobs/Jobs templates
  (incl. replicas=0), Talos core images (kubelet, kube-*, from machineconfig), kopiur mover images (find in kopiur
  config/HelmRelease values — CRITICAL for PVC restore), NAS compose images (from repo or a ConfigMap generated in
  repo), bootstrap chart refs. For each: GET index + `linux/amd64` child via `nas.internal:5010/<host>/...`
  (crane/regctl `--insecure`). Charts: pull chart manifest.
- effect: fills cache for never-repulled images (IfNotPresent) + refreshes pull stats -> retention keeps in-use set.
- RBAC: list workloads cluster-wide (read-only ClusterRole).
- accept: after run, zot-cache catalog contains every running image; spot-check with `crane digest`.

### T8 relax cache retention (SHOULD)

- `docker/zot/config/cache.yaml`: keepTags `mostRecentlyPulledCount: 3` + `pulledWithin: 720h`;
  keepUntagged same. Rationale: NAS+cluster share repos at different versions; multi-version repos (1.3).
- user originally chose "keep 1 most recent tag" -> CONFIRM change with user.

### T9 offline drill (SHOULD)

- run zot-cache with upstreams unreachable (e.g. temporary compose override with bogus DNS / network without egress)
  and test: tag pull falls back to local, digest pull served, timing acceptable. Measure bootstrap-scale latency.
- consider `manifestCheckInterval` only if timings bad (note: in-memory, resets on restart).

### T10 TLS without internet (COULD)

- `letsencrypt-production` cannot issue offline. Options: back up envoy-gateway certificate secret (kopiur/borg?),
  or temporary switch to `openbao` issuer during DR. Document in runbook.

### T11 runbook (MUST, last)

- write `DR-RUNBOOK.md` (human readable) from section 2 + task outputs: exact commands, order, secrets needed
  (openbao unseal key, VAULT_TOKEN, zot API key, arcane envs), verification per step.

## 4. Priority order

T7 -> T1 -> T2 -> T3 -> T6 -> T4 -> T5 -> T8 -> T9 -> T10 -> T11.
(T7 first: K1 hurts the running cluster today, not only DR.)

## 5. Unavoidable internet (document, do not solve unless asked)

- BorgBase restore (unless user keeps local/offline borg copy) -> suggest local repo copy.
- TrueNAS install media.
- LE certs (T10 mitigates).
- new talos-factory builds (8.D2).
- app runtime downloads; nix paths not in ncps.

## 6. Open questions (ask user)

- Q1: which `docker/*` stacks run on VPS vs NAS?
- Q2: where does Arcane manager run; how are NAS stacks deployed (git pull from github?) -> offline deploy path.
- Q3: OK to relax cache retention (T8)?
- Q4: T5 option A (runbook) or B (CI artifact)?
- Q5: local offline copy of borg repos acceptable/possible?

## 7. Gotchas from zot rollout (avoid repeating)

- bind-mount dirs auto-created by docker are root-owned; zot runs 1000:1000 -> pre-create + chown (sync downloadDir
  failed silently with permission denied while container reported healthy).
- zot config extension decides parser (YAML must be `.yaml`).
- `docker compose` not available in sandbox; validate compose with `yq 'explode(.)'`; validate zot config with
  extracted binary `zot verify` (crane export image, path `usr/local/bin/zot-linux-amd64`).
- sandbox cannot reach `*.ajgon.casa` over HTTPS; docker access = logs/inspect only (read-only socket proxy).
- markdown/yaml line limit 120 (`.markdownlint.yaml`, `.yamllint`).
- keep secrets out of config files: init container pattern (`ncps-secret`, `zot-secrets`, `talos-factory-secrets`).

## 8. Decisions log

- D1: single zot-cache instance, path-prefixed upstreams, Talos `overridePath` (user choice).
- D2: talos-factory core artifacts stay direct ghcr.io; reason: zot tags/list local-only breaks factory version
  discovery. Revisit only with periodic sync of `siderolabs/imager` (heavy).
- D3: zot-registry pushes via API key; cache stays anonymous.
- D4: talos-factory does NOT push into zot-cache (retention would delete schematics; anon-writable).

## 9. Dropped ideas

- DROPPED: persistent volume for Flux source-controller (only helps a running cluster, not rebuild).
- DROPPED: talos-factory pulling via zot-cache (D2).
