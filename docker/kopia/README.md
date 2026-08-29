# kopia

Daily backups of the NAS host's data, as extra sources inside the **two
repositories the cluster already uses**:

| Source                 | garage | b2  | Previously covered by |
| ---------------------- | ------ | --- | --------------------- |
| `/mnt/fast/backups`    | ✅     | ✅  | borgmatic `homelab`   |
| `/mnt/fast/docker`     | ✅     | ✅  | borgmatic `homelab`   |
| `/mnt/tank/documents`  | —      | ✅  | borgmatic `nas`       |
| `/mnt/tank/photos`     | —      | ✅  | borgmatic `nas`       |
| `/mnt/tank/private`    | —      | ✅  | borgmatic `nas`       |

`/mnt/tank` goes offsite only. Garage runs on the same disks, so a local copy of
a large dataset buys little beyond what ZFS already provides — B2 is where it
actually needs to be. `/mnt/fast` is small enough to keep in both.

The destinations:

| Service     | Endpoint                            | Bucket                 | Shared with           |
| ----------- | ----------------------------------- | ---------------------- | --------------------- |
| `kopia-nas` | `s3.ajgon.casa` (garage)            | `backup-homelab`       | kopiur `nas`          |
| `kopia-b2`  | `s3.eu-central-003.backblazeb2.com` | `ajgon-homelab-backup` | kopiur `backblaze-b2` |

These are the same repositories declared in
`kubernetes/apps/kopiur-system/kopiur/clusterrepository.yaml`. Nothing new is
created — the NAS just adds snapshot sources under a different identity, so the
whole fleet stays at two repositories and the existing
`kopia-nas.${ROOT_DOMAIN}` / `kopia-b2.${ROOT_DOMAIN}` pods already show
everything.

## Identity and isolation

Snapshots are namespaced by `user@host:path`. The NAS connects as **`root@nas`**
(set in the `repository.config` files). Nothing else in these repositories uses
the hostname `nas`:

| Who                     | Identity                                     |
| ----------------------- | -------------------------------------------- |
| NAS (this stack)        | `root@nas`                                   |
| kopiur's snapshots      | `<app>@<namespace>`, e.g. `airtrail@default` |
| kopiur's kopia UI pods  | `kopiur@kopiur`                              |
| kopiur's maintenance    | `kopiur@kopiur-clusterrepository-<repo>`     |

That separation is what keeps the two sets of snapshots apart while still
sharing blobs and deduplication.

It is also what stops the cluster from touching NAS sources. `isLocal` in
`internal/server/server.go:1020` compares **hostname only**, so the cluster's
kopia pods (hostname `kopiur`) see `root@nas:/mnt/fast/backups` as a remote
source, mark it `REMOTE`, and run `runReadOnly()` — browsable and restorable
there, never scheduled there.

## What this stack must not do

Both repositories are owned by kopiur, so the NAS side stays strictly
source-scoped:

- **No `repository create`.** They exist; a stray create against an empty bucket
  would fork the fleet's backups into a second repository.
- **No global policy.** The global policy applies to the entire repository,
  including every cluster `SnapshotPolicy`. All retention here is written per
  source, to each `root@nas:<path>`, instead.
- **No maintenance ownership.** kopiur holds the lease
  (`Maintenance/{nas,backblaze-b2}`, `takeoverPolicy: Never`, quick `0 */6 * * *`,
  full `0 3 * * *`). Claiming it as `root@nas` would stop the cluster's
  maintenance from running.

In practice that means every command run against these repositories from the NAS
should be a source-scoped `policy set`/`policy show`, or a read-only
`repository status`/`maintenance info`. Never `repository create`,
`policy set --global` or `maintenance set`.

## Scheduling

Snapshots are driven by `kopia server`'s built-in scheduler, not by cron. The
schedule is a *repository-side* policy (`scheduling.cron` on each
`root@nas:<path>`), written once when the source is added — it is
**not** in this compose file. `--run-missed=true` means a snapshot skipped while
the container was down runs on the next start, which matters more at daily
cadence than it did hourly.

Because the policies live in the repository, **a new repository has none.** The
containers come up, connect, and sit idle with nothing to schedule — no error,
no log line, just silence. That is exactly what happened on 2026-08-29 when b2
was rebuilt into `ajgon-homelab-backup`. `--run-missed` does not rescue it
either: "missed" is measured against a source's snapshot history, and a new
source has none, so the next run is simply tomorrow's slot. After any repository
rebuild, re-run the `register` block below **and** kick off the first snapshot
per source by hand (`kopia snapshot create <path>`, serially — the seed is slow).

The two repositories are staggered an hour apart so they never walk the same
disks at the same time:

| Repository                  | Cron           | Local time |
| --------------------------- | -------------- | ---------- |
| `backup-homelab` (garage)   | `30 12 * * *`  | 12:30      |
| `ajgon-homelab-backup` (b2) | `30 13 * * *`  | 13:30      |

Both are clear of everything else on the box: borgmatic was moved to 14:30
(`BACKUP_CRON` in `docker/borgmatic/compose.yaml`), kopiur's quick maintenance
(`0 */6 * * *` ±30m) covers 00:00, 06:00, 12:00 and 18:00, and its full
maintenance (`0 3 * * *` ±1h) covers 03:00–04:00.

Maintenance is kopiur's job, not ours; these containers only snapshot.

## Retention

Written to the source policy, not the global one:

```text
--keep-latest 3  --keep-hourly 0  --keep-daily 7  --keep-weekly 4  --keep-monthly 12  --keep-annual 0
```

`--keep-hourly 0` because the cadence is daily. Kopia keeps the newest snapshot
per time bucket, so at one snapshot per day each lands in its own hour bucket and
any non-zero `keep-hourly` would just retain that many dailies, subsuming
`keep-daily`. It is set explicitly rather than omitted — omitting it inherits
whatever the policy already has.

Retention prunes snapshot manifests at snapshot time; the underlying blobs are
reclaimed later by the full maintenance kopiur runs.

## Monitoring

`kopia-b2-monitor` runs three independent jobs against the b2 repository and
reports each to its own healthchecks.io check. Garage is deliberately not
monitored; only the offsite copy is.

| Job         | When                | Slug                   | What it asserts                                 |
| ----------- | ------------------- | ---------------------- | ----------------------------------------------- |
| **backups** | daily 20:00         | `kopiur-backups`       | every source has a completed snapshot < 12h old |
| **quick**   | every 3 days, 05:00 | `kopiur-verify-quick`  | `snapshot verify` — blob-level integrity        |
| **deep**    | 1st of month, 07:00 | `kopiur-verify-deep`   | `snapshot verify --verify-files-percent 100`    |

`HEALTHCHECKS_URL` is the host and ping key only — e.g.
`https://hc-ping.com/<ping-key>`. The script appends the slug, and `/fail` on
failure, with the diagnostic as the request body so the alert names the problem.
Both verify tiers also ping `/start`, so healthchecks shows run duration and can
alert on a run that begins but never finishes.

Slots are chosen to stay clear of kopiur's equivalents, which run against the
same repository — kopiur quick at `H 3 */3 * *`, kopiur deep at `H 4 1 * *`,
plus its maintenance at 03:00–04:00 and 00/06/12/18. Ours sit at 05:00 and
07:00, after all of them.

### Why verify outcomes rather than hook events

- **Webhook notifications** (`kopia notification configure webhook`) gate on
  `--min-severity` only — a profile aimed at the success URL also fires on
  warning and error, so a failed backup would turn the check green. There is no
  max-severity. It also emits one report per source rather than per run
  (`endUpload`, `internal/server/server.go:558`, with `MaxParallelSnapshots` at
  1), so any single success would mask another source rotting.
- **Actions** (`--after-snapshot-root-action`) would work but need
  `enableActions: true`, scripts stored in the shared repository's policies, and
  one healthchecks check per source.

Checking results instead catches things no event hook can see: a policy deleted,
a source dropped from the list, the server never having come up.

### Scheduling Notes

- **`--sources` is always passed explicitly.** With no source arguments,
  `snapshot verify` walks *every* manifest in the repository
  (`loadSourceManifests`, `cli/command_snapshot_verify.go:208`) — which here
  would mean verifying the entire cluster's backups too. Not our job, and
  enormously expensive.
- **Deep egress is roughly one copy of the dataset, not one per snapshot.** The
  tree walker keeps an `enqueued` set keyed by object ID
  (`snapshot/snapshotfs/snapshot_tree_walker.go:27`), so a single invocation
  downloads each unique object once across all sources and retained snapshots.
  Still worth watching against B2's free egress allowance (3× stored bytes per
  month); drop `DEEP_FILES_PERCENT` if it bites.
- **A `kopiur-verify-*` failure is more often Backblaze than corruption.** B2's
  S3 gateway intermittently answers a read with correct headers and an empty
  body, so kopia reports `unexpected EOF` or `error getting blob`. It is
  per-object, ranges from ~40% of requests to 100%, and decays to zero on its
  own over minutes to hours. The object is undamaged throughout — a retried full
  GET returns the declared length, and `backblaze-b2 file download` verifies the
  SHA1. Confirm that way before treating a verify failure as data loss. On
  2026-08-29 this defect caused a 13-hour repository outage and 43 false
  "damaged blob" findings without a single byte being lost.
- **Run state lives in `/config/monitor-state`**, so a container restart cannot
  re-trigger a multi-hour deep verify, and a slot missed while the container was
  down runs on the next poll rather than being skipped for a month.
- The sidecar opens its own **read-only** connection
  (`config/repository-b2-monitor.config`) rather than reaching into
  `kopia-b2-host`, which would have meant handing it the docker socket. It
  mounts no source data and drops all capabilities — it only reads the
  repository. Both `snapshot verify` and `restore` are `repositoryReaderAction`,
  so read-only is sufficient.
- Jobs run sequentially in one loop. A long deep verify delays that day's
  backups check rather than dropping it.

Tunable via compose: `BACKUPS_AT`, `BACKUPS_MAX_AGE_HOURS`, `QUICK_AT`,
`QUICK_EVERY_DAYS`, `DEEP_AT`, `DEEP_DAY_OF_MONTH`, `DEEP_FILES_PERCENT`. Set
each healthchecks check's period and grace to match — 1 day, 3 days and 1 month
respectively, with grace generous enough for a slow run.

## `CACHEDIR.TAG`

Handled natively — kopia skips any directory containing a `CACHEDIR.TAG` whose
first 43 bytes are `Signature: 8a477f597d28d172789f06886806bc55`
(`fs/ignorefs/ignorefs.go`). This is on by default; `add` sets
`--ignore-cache-dirs=true` explicitly so it survives a policy edit in the UI.

## Environment

Supplied through the stack's `.env`, like every other NAS stack. The values are
the same secrets kopiur uses — this is the same repository, so the password must
match exactly:

| Variable                          | Purpose                                |
| --------------------------------- | -------------------------------------- |
| `KOPIA_PASSWORD`                  | repository encryption password (both)  |
| `KOPIA_NAS_AWS_ACCESS_KEY_ID`     | garage access key                      |
| `KOPIA_NAS_AWS_SECRET_ACCESS_KEY` | garage secret key                      |
| `KOPIA_B2_AWS_ACCESS_KEY_ID`      | backblaze b2 application key id        |
| `KOPIA_B2_AWS_SECRET_ACCESS_KEY`  | backblaze b2 application key           |
| `KOPIA_B2_HEALTHCHECKS_URL`       | hc-ping host + key, no slug            |
| `DATA_DOCKER_DIR`                 | stack-wide, already defined            |

kopia reads the credentials via minio-go's `EnvAWS` provider, which is why the
`repository.config` files carry no keys — only bucket, endpoint and region.

## Adding a source

Source-side state — retention, compression, cache-dir handling, schedule — lives
in the repository, not in git. The containers are already connected, so adding a
source is one kopia command per repository, run inside the container:

```sh
fast=(/mnt/fast/backups /mnt/fast/docker)
tank=(/mnt/tank/documents /mnt/tank/photos /mnt/tank/private)

register() {
  local c="$1" cron="$2"
  shift 2
  for s in "$@"; do
    docker exec "$c" kopia policy set "root@nas:${s}" \
      --keep-latest 3 --keep-hourly 0 --keep-daily 7 \
      --keep-weekly 4 --keep-monthly 12 --keep-annual 0 \
      --ignore-cache-dirs=true --compression zstd \
      --snapshot-time-crontab "${cron}" --run-missed=true
  done
  docker kill -s HUP "$c"
}

# garage: /mnt/fast only          b2: everything
register kopia-nas-host "30 12 * * *" "${fast[@]}"
register kopia-b2-host  "30 13 * * *" "${fast[@]}" "${tank[@]}"
```

A path must be mounted into the container before a policy for it will do
anything — see the `volumes:` list in `compose.yaml`.

No connect step and no credentials to pass: the image already sets
`KOPIA_CONFIG_PATH=/config/repository.config` and `KOPIA_CACHE_DIRECTORY`, and
the container holds `KOPIA_PASSWORD`.

The `SIGHUP` is the part that is easy to miss. A policy written by the CLI
bypasses the server's own API, so the running server would not notice the new
source until its next periodic repository refresh — `--refresh-interval`,
default **4h** (`cli/command_server_start.go:96`). SIGHUP is wired to
`Server.Refresh()` (`cli/command_server_start.go:298`), which re-runs source
discovery immediately. `docker compose restart` works too, just less politely.

Same shape for everything else you might want:

```sh
docker exec kopia-nas-host kopia policy show root@nas:/mnt/tank/photos
docker exec kopia-nas-host kopia snapshot list root@nas:/mnt/tank/photos
docker exec kopia-nas-host kopia maintenance info   # lease should read kopiur/...
```

Within a repository all five sources share one cron, but they do not run at once:
`MaxParallelSnapshots` defaults to 1, so each server works through its sources
serially. That is also why the two repositories are an hour apart rather than
simultaneous — a serial pass over five trees is not instant. Expect the first
pass over `/mnt/tank/photos` to take a while against B2, possibly past 14:30 on
day one; subsequent runs are incremental and deduplicated against whatever the
cluster has already uploaded.

**Record `KOPIA_PASSWORD` somewhere outside this cluster.** Without it both
repositories are unrecoverable.

## Notes

- No Traefik routes and no subdomains. The servers bind `127.0.0.1:51515` with
  `--no-ui`, so they are unreachable from outside the container; browsing
  happens in the existing cluster pods. `--without-password` requires
  `--insecure`, and that combination restricts the bind to loopback
  (`internal/insecureserverbind`) — which is exactly what we want.
- **`--no-ui`, not `--ui=false`.** kopia's CLI is kingpin, where a genuine bool
  flag takes its value from the flag name and never consumes a following token
  (`flags.go:114`), so `--ui=false` leaves `false` as a stray positional and the
  server exits 1 with `unexpected false`. Inversion is spelled `--no-<flag>`.
  Note this does *not* apply to the `policy set` flags: `--ignore-cache-dirs`
  and `--run-missed` are `EnumVar` string enums (`true`/`false`/`inherit`), so
  they genuinely do want `=true`.
- `KOPIA_WEB_ENABLED: "false"` makes the image entrypoint exec kopia with our
  args verbatim instead of wrapping them in its own `server start` on `0.0.0.0`.
- Containers run as `root` because kopia has to read the whole source tree, and
  additionally need `cap_add: DAC_READ_SEARCH`. uid 0 with an empty capability
  set is still subject to normal DAC checks, so without it any source file or
  directory that is not world-readable fails the snapshot with
  `upload error: permission denied` — everything else stays dropped, and every
  source is mounted read-only. (borgmatic never hit this because it runs with
  the default full capability set.)
- The source list is taken from `docker/borgmatic/config/{homelab,nas}.yaml` —
  paths only. borgmatic still backs all five up daily to BorgBase with its own
  retention; this stack is additive and nothing here touches it.
- The B2 repository carries a GOVERNANCE object lock (168h). Nothing to
  configure here: kopiur stamps it per blob via its `blobRetention`, and
  `ajgon-homelab-backup` also has it as a bucket default, which is what covers
  our uploads since this stack sets no retention of its own.
