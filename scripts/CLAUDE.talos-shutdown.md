# `talos-shutdown.sh` — context

Full-cluster shutdown for the `deedee` Talos cluster (nodes `blossom` / `bubbles` /
`buttercup`, `192.168.42.21-23`). Everything here was learned the hard way on
2026-08-01, mostly by reading the Talos source and probing the live cluster.

The script deliberately carries **no comments** — this file is its documentation.
Do not re-add explanatory comments to the script; extend this file instead.

## Running it

```sh
./scripts/talos-shutdown.sh              # interactive
./scripts/talos-shutdown.sh --dry-run    # preflight + plan, changes nothing
./scripts/talos-shutdown.sh --ups        # unattended, driven by ups-cascade
```

Interactively it asks nothing. Running it *is* the decision; it is destructive
from the first `kubectl cordon`. Timeouts are `DRAIN_TIMEOUT` and `MOUNT_TIMEOUT`
at the top of the file (env-overridable, default 600s).

Flow: `preflight → cordon_all → drain_all → wait_for_mounts_drained → shutdown_nodes`

**After power-on the only required step is `kubectl uncordon blossom bubbles buttercup`.**
Nothing else: no replica counts are changed, Flux is never suspended, no Ceph
flags are set. The script prints the uncordon line as its last output. Under
`--ups` that uncordon is done for you on boot by `ups-cascade-recover.service`.

## `--ups` mode

Added 2026-08-07 for the `ups-cascade` Ansible role, which runs this script from
the NUT primary (`nutpi`) when the UPS has been on battery past its ride-through.
The invariant in "The failure it exists to prevent" is unchanged; what changes is
that **the script may no longer refuse to act**. A power cut is coming either
way, so every path that interactively calls `die` instead degrades to
`force_shutdown_all` — `talosctl shutdown --force` on every node, crash-consistent
but never wedged.

Behavioural differences, all of them consequences of that:

| Interactive | `--ups` |
| --- | --- |
| `gum` logging | plain timestamped stderr |
| non-`HEALTH_OK` Ceph aborts | logs `talos_ceph_unhealthy`, proceeds |
| unreachable API/toolbox aborts | falls back to `force_shutdown_all` |
| missing `kubectl`/`jq` aborts | falls back to `force_shutdown_all` |
| node list from `kubectl` | falls back to `UPS_NODES` |
| live mounts at timeout aborts | logs `talos_mounts_timeout`, proceeds |
| `DRAIN_TIMEOUT` / `MOUNT_TIMEOUT` 600s | `UPS_DRAIN_TIMEOUT` 180s / `UPS_MOUNT_TIMEOUT` 120s |
| no overall limit | `UPS_DEADLINE` 420s caps everything |

Only one thing is still fatal under `--ups`: a missing `talosctl`, since without
it the script cannot shut anything down at all. It exits 1 and the orchestrator
moves straight on to the NAS.

### The budget

`UPS_DEADLINE` is wall-clock from process start. `capped()` clamps each gate's
timeout to whatever is left, so `UPS_DRAIN_TIMEOUT` and `UPS_MOUNT_TIMEOUT` are
ceilings rather than guarantees, and the mount gate re-checks `budget_left` on
every pass. Exhausting the budget is not an error — it is the designed exit into
`force_shutdown_all`. The orchestrator keeps its own backstop at
`UPS_DEADLINE + 60`, after which it kills the process group and forces the
shutdown itself.

Every constant lives in one block at the top of the file and every one is
env-overridable; `ups-cascade` sets `UPS_DEADLINE`, `UPS_DRAIN_TIMEOUT`,
`UPS_MOUNT_TIMEOUT` and `UPS_NODES` from its own `defaults/main.yaml`.

### `@@UPS_EVENT` lines

Under `--ups` the script writes machine-readable progress to **stdout**, one per
line, as `@@UPS_EVENT <name> [k=v ...]`. The orchestrator parses these, attaches
UPS telemetry, and appends them to `/var/lib/ups-cascade/events.jsonl`; anything
else on stdout/stderr is passed through to the journal untouched.

**Values must not contain whitespace.** The parser splits the line on whitespace
and keeps only tokens containing `=`, so a spaced value is silently truncated at
its first word and the remainder is discarded — no error, just a wrong log entry.
This bit once (2026-08-09): `nodes="${NODE_NAMES[*]// /,}"` looks like it joins
the array with commas but does not. For an array, `${arr[*]//pat/rep}` substitutes
inside *each element* and only then joins with `IFS`, so the result stayed
space-separated and `talos_preflight_ok` logged a single node. Join explicitly
with a subshell that sets `IFS`, and use `${var// /_}` for scalars that may
contain spaces, as `talos_ceph_unhealthy` does with Ceph's health string.

`talos_preflight_ok`, `talos_preflight_degraded`, `talos_ceph_unhealthy`,
`talos_cordoned`, `talos_drained`, `talos_mounts_clear`, `talos_mounts_timeout`,
`talos_point_of_no_return`, `talos_shutdown_issued`, `talos_forced`,
`talos_dry_run`, `talos_aborted`.

**`talos_point_of_no_return` is the one that matters.** It is emitted
immediately before the first `talosctl shutdown` of either path, and it is what
tells the orchestrator that aborting is no longer permitted — a half-powered-off
cluster is the wedge state, so once the first node has been told to go, they all
go. Do not move this emission later, and do not add a code path that shuts a node
down without emitting it first.

### `--dry-run`

Runs `preflight` and prints the plan. Mutates nothing — no cordon, no drain, no
shutdown — so it is safe at any time and is the only way to exercise the
credentials, the API reachability and the Ceph mount-pattern discovery without
committing. Combines with `--ups` (that is how the orchestrator's own dry-run
mode invokes it), in which case preflight degradation is reported as
`talos_dry_run degraded=<0|1>` rather than acted on.

## The failure it exists to prevent

`talosctl shutdown` against all nodes at once drains them *simultaneously*. That
evicts the Rook mons/OSDs/MDS with nowhere to reschedule, Ceph loses quorum, and
every kernel RBD/CephFS mount on the nodes wedges in uninterruptible I/O. kubelet
can then never unmount `/var/lib/kubelet`, so Talos hangs forever in
`stopAllPods` and the only way out is a hard power-off.

Observed signature (2026-08-01, before the script existed):

```text
[talos] task cordonAndDrainNode (1/1): done, 5m2.971089169s
[talos] task stopAllPods (1/1): waiting for kubelet lifecycle finalizers
[talos] task stopAllPods (1/1): shutting down kubelet gracefully
block.MountController: waiting for mount status to be torn down  mount_request=/var/lib/kubelet
libceph: mon1 (2)192.168.42.21:3300 socket closed (con state V2_BANNER_PREFIX)
ceph: [<fsid>]: mds0 hung
```

Recovery from that state is `talosctl shutdown --force`, or IPMI/PDU power-off if
machined refuses because a sequence is already running. It is crash-consistent —
BlueStore and Postgres both replay their WAL — but it is a power cut.

### Draining one node at a time does NOT fix it

This is the trap worth remembering. **Drain moves pods, it does not stop them.**

- Drain `blossom` → its workloads reschedule onto `bubbles`/`buttercup` and
  immediately re-map the same RBD images there. It also evicts `osd-0` and
  `mon-a`, because *every Ceph daemon here is a Deployment*, not a DaemonSet.
  Ceph: 2/3 OSDs, 2/3 mons.
- Drain `bubbles` → everything piles onto `buttercup`. `osd-1` evicts → 1 OSD,
  below `min_size 2` → all PGs inactive. `mon-b` evicts → quorum lost. Every
  mount on `buttercup`, which now holds *all* the workloads, freezes.

Each step subtracts Ceph capacity while leaving the client count unchanged, and
concentrates every mount onto the last node exactly as Ceph falls below
`min_size`.

## The invariant

> At the instant Ceph drops below quorum/`min_size`, there must be zero Ceph
> client mounts on any node.

Everything in the script serves this. The mechanism (drain vs. scale-to-0) is
arbitrary; the ordering is not.

`cordon_all` before any drain is what makes drain usable: with every node
unschedulable, eviction becomes *termination* instead of relocation.
`wait_for_mounts_drained` is the hard gate that proves the invariant holds before
anything is powered off.

## Design decisions — things deliberately NOT done

Each of these was in an earlier version and was removed for a reason. Do not
re-add without reading the reason.

### No Flux suspend

The drain-based design changes no replica counts, so Flux has nothing to revert.
If it reconciles mid-shutdown it just recreates pods that go `Pending` on
cordoned nodes, and Pending pods hold no mounts, so the gate is unaffected. A
forgotten `flux resume` silently stops all GitOps — a worse failure than anything
suspension prevents.

### No Rook operator scale-down

The drain selector keeps every Ceph daemon running, so the operator has nothing
to reconcile against.

### No `ceph osd set noout/pause/...`

The usual full-cluster-shutdown advice assumes clients stay attached and OSDs
stay down a long while. Neither holds here: every client is gone (the mount gate
proved it) and the whole fleet is off inside a minute, so mon quorum disappears
long before `mon_osd_down_out_interval` (600s) could mark anything out. The flags
prevent nothing, persist in the mon store, and must be unset by hand — and a
forgotten `pause` leaves the cluster frozen on boot with no obvious cause.

Pathological case without them: one node fails to power off, its OSD is marked
out after 10 min, and with `failureDomain: host` across 3 hosts there is nowhere
to re-replicate. PGs sit degraded but active. No data movement. Benign.

### No confirmation prompt, no `--yes`

Running the script is the decision. The `HEALTH_OK` preflight is a precondition
gate, not a safety prompt — it is not there to catch accidental invocation, and
nothing else is either.

`--dry-run` and `--ups` (2026-08-07) do not contradict this. Neither is a safety
prompt: `--dry-run` mutates nothing whatsoever, and `--ups` exists because during
a power event *refusing to act* is the dangerous choice. There is still no
`--yes`, no confirmation, and no way to make a real run interactive.

### No `talos.dev/cordoned` annotation — this actively backfires

Tried on 2026-08-01 to get a free uncordon on boot. It made things *worse*.

`k8s.NodeApplyController.ApplyCordoned` runs continuously, not only at shutdown:

```go
case shouldCordon && !node.Spec.Unschedulable:
    node.Spec.Unschedulable = true
    node.Annotations[AnnotationCordonedKey] = AnnotationCordonedValue
case !shouldCordon && node.Spec.Unschedulable:
    if _, exists := node.Annotations[AnnotationCordonedKey]; !exists {
        return  // "not cordoned by Talos, skip"
    }
    node.Spec.Unschedulable = false
    delete(node.Annotations, AnnotationCordonedKey)
```

`shouldCordon` is true only for `MachineStageShuttingDown|Upgrading|Resetting`,
false for `Booting|Running`. When the script cordons and annotates, the machine
is still `Running` → second branch → **Talos uncordons the node and deletes the
marker, mid-drain**, reopening it for scheduling and breaking the core invariant.
The nodes ended up cordoned again only because `kubectl drain` re-cordons each
node it touches.

It is unfixable, not merely mistimed: Talos only sets the marker on a node it
found *schedulable* at shutdown time (`shouldCordon && !Unschedulable`), so a
pre-cordoned node can never inherit it, and anything stamped manually is deleted
while the machine is Running. Pre-cordoning and Talos-owned uncordon are mutually
exclusive. Hence the manual `kubectl uncordon` on boot.

## The drain selector

```text
--pod-selector='rook_cluster!=rook-ceph'
```

`rook_cluster` is on every Ceph daemon Rook runs — mon, osd, mgr, mds,
crashcollector, exporter — exactly the set that must stay up while workloads
unmount. A `!=` selector also matches pods lacking the key entirely, so ordinary
workloads are still drained.

The operator, tools and ctrlplugins do **not** carry the label and get drained.
That is fine: unmounting runs through `NodeUnstage`/`NodeUnpublish` in the CSI
**nodeplugin**, which is a DaemonSet and exempt via `--ignore-daemonsets`. The
ctrlplugin only handles `ControllerUnpublish`; the operator is not in the data
path.

Verified against the live cluster (2026-08-01): 16 pods protected, all in
`rook-ceph` (3 mons, 3 OSDs, 2 mgrs, 2 MDS, crashcollectors, exporters); 183 of
199 pods selected for drain; nothing outside `rook-ceph` shielded.

### There is no "drain last" or "non-drainable" marker in Kubernetes

Confirmed by exhausting the alternatives:

- **priorityClassName** — irrelevant. The Ceph daemons already carry
  `system-node-critical` (mons, OSDs) and `system-cluster-critical` (mgr, MDS).
  Drain ignores priority entirely; it governs scheduler preemption and kubelet
  node-pressure eviction, not API-driven drain.
- **PDBs** — they *block* eviction, they do not *skip* it. Drain retries until
  `--timeout` then fails the node. Rook already creates `rook-ceph-mon-pdb`,
  `rook-ceph-osd`, `rook-ceph-mgr-pdb`, `rook-ceph-mds-ceph-filesystem`.
- **DaemonSet exemption** — the only true skip, and Rook runs mons/OSDs as
  Deployments. Not changeable.
- **Talos config** — no drain knob exists at all (see below).

A pod-selector is the only mechanism available.

### Optional hardening: own the label

To stop depending on Rook's internal label, stamp your own via the HelmRelease —
`cephClusterSpec.labels.all` plus `cephFileSystems[].spec.metadataServer.labels`
(both confirmed present in the CRDs) — and match on that. Cost: changing labels
makes Rook update the daemon Deployments, **rolling every mon and OSD**. Given
the June 2026 deadlock was triggered by a simultaneous OSD bounce, do it
deliberately on a healthy cluster, never right before a shutdown.

## `--disable-eviction` is required

It deletes pods directly instead of using the eviction API. Pods still get their
normal termination grace period; what it skips is PDB gating, which would
otherwise deadlock — a PDB demanding `minAvailable: 1` can never be satisfied
when no node is schedulable.

Not theoretical: `ai-db-primary`, `immich-db-primary` and `shelf-db-primary` all
show **ALLOWED DISRUPTIONS = 0**. Without this flag the drain hangs on them.

## Ceph mount detection

**Never pattern-match the mount source.** CephFS on this cluster renders as:

```text
csi-cephfs-node.1@<fsid>.ceph-filesystem=/volumes/csi/csi-vol-.../<uuid>
```

— which contains no `:/` at all, while the NAS NFS mounts
(`nas.internal:/mnt/fast/media`) *do*. The obvious `host:/path` heuristic
therefore fails in **both** directions: it matches zero CephFS mounts (the
dangerous direction — the gate passes while CephFS is live) and flags every NFS
mount as Ceph (blocking direction).

Derive from cluster state instead: Ceph CSI **driver names** appear in
`globalmount` paths, and Ceph **PV names** appear in per-pod paths. That is what
`build_ceph_mount_patterns` collects, fed to `grep -F -f`.

`talosctl mounts` columns are `NODE FS SIZE USED AVAIL PCT MOUNTED_ON`.
`/var/mnt/rook-ceph` is the local `dataDirHostPath`, not a client mount, and is
excluded by the `/var/lib/kubelet` prefix test.

Verified: 50/34/67 Ceph mounts found across the three nodes, 0 NFS false
positives.

## Talos internals (verified against source at tag `v1.13.7`)

Cloned from `github.com/siderolabs/talos`. Findings:

**The built-in shutdown drain cannot be customised.** There is no drain
configuration in the machine config schema at all — generating the full config
docs (`talosctl docs --config`, 54 files) gives 0 hits for `drain`, `cordon`,
`shutdown`, `gracePeriod`; the single `evict` hit is OOM cgroup ranking.

Two separate drain implementations exist, neither takes a selector:

1. **Server-side**, what `talosctl shutdown` triggers —
   `internal/app/machined/pkg/runtime/v1alpha1/v1alpha1_sequencer_tasks.go:836`
   `CordonAndDrainNode` ignores both its params and calls
   `kubeHelper.Drain(ctx, nodename)` (`pkg/kubernetes/kubernetes.go:239`).
   Signature takes no options; lists pods with only a `FieldSelector` on node
   name, no `LabelSelector`. Hardcoded skips: mirror pods, pods with nil
   `controllerRef`, DaemonSet pods. Grace period literal `int64(60)`.
   `DrainTimeout = 5 * time.Minute` (`kubernetes.go:40`) — matches the observed
   `5m2.97s`. Wired as `.AppendWhen(!in.GetForce() && !skipNodeRegistration, ...)`,
   so `--force` is the only switch.
2. **Client-side**, `talosctl reboot --drain` —
   `cmd/talosctl/pkg/talos/nodedrain/nodedrain.go` uses `drain.Helper` from
   `k8s.io/kubectl/pkg/drain` v0.36.2, the same library `kubectl drain` uses.
   That struct *does* have `PodSelector string` (drain.go:65, parsed at :185),
   but Talos builds the Helper from a hardcoded literal and never sets it. The
   exposed `Options` struct has exactly one field, `DrainTimeout`. `rg PodSelector`
   across the whole repo: **zero hits**.

There is no `talosctl drain` command in v1.13.7.

Hence: use `talosctl shutdown --force` to disable Talos' drain entirely and drive
`kubectl drain --pod-selector` yourself. That is not a workaround, it is the only
available path.

Incidental upstream bug: in `Drain()`, the `if !pod.DeletionTimestamp.IsZero()`
branch logs `"skipping deleted pod"` but has no `return nil`, so it falls through
and evicts anyway. Harmless.

## Cluster facts

- 3 control-plane nodes, hyperconverged: the OSD nodes also mount the cluster's
  own RBD/CephFS volumes. This is what makes the deadlock possible at all.
- Pools `size 3` / `min_size 2`, `failureDomain: host`.
- Rook chart pinned `v1.20.3`; `cephVersion.image` is **not** pinned and there is
  no renovate `allowedVersions` constraint (`.renovate/groups.json5:55` only
  groups the packages). A chart bump can therefore still carry a Ceph major
  upgrade — the exact trigger of the June 2026 deadlock. Worth fixing.
- API VIP `192.168.42.20:6443`. Node names map to InternalIPs `.21/.22/.23`;
  `kubectl` needs names, `talosctl` needs addresses, hence `NODE_ADDR`.

### Break-glass: OSD activation deadlock

If OSD pods hang in `Init:0/4` with D-state `ceph-volume`/`lvs` processes, PGs
below `min_size` never go active, RBD I/O freezes on the same nodes running the
OSDs, and `ceph-volume`'s device scan wedges. Drop `min_size` so PGs activate:

```sh
ceph osd set noout
ceph osd pool set <pool> min_size 1   # each pool
# ... OSDs activate ...
ceph osd pool set <pool> min_size 2
ceph osd unset noout
```

## Real-run result (2026-08-01)

Ran successfully; all three nodes powered off cleanly, no deadlock. `bubbles`,
which hung at `stopAllPods` in the incident, got all the way through:

```text
task stopAllPods (1/1): shutting down kubelet gracefully
volume status  "volume": "u-rook-ceph", "phase": "ready -> closed"
XFS (dm-1): Unmounting Filesystem
volume unmount  "volume": "EPHEMERAL", "target": "/var"
```

`buttercup` logged `EXT4-fs (rbd8): unmounting filesystem` — a clean RBD unmount
while Ceph was still healthy, which is the whole point.

The run also exposed the `talos.dev/cordoned` bug documented above.

## Known limitations

- The `HEALTH_OK` preflight gate is strict **interactively**. If the cluster
  routinely sits at `HEALTH_WARN` for benign reasons (overdue scrub, clock skew,
  stray `noout`) the script refuses to run and the only override is `--ups`,
  which sidesteps the check rather than fixing it. The narrower correct check
  would still be "an OSD is down/out or PGs are not active".
- Unknown arguments are now rejected with a usage message. Before 2026-08-07 they
  were silently ignored.
- A failed drain is not fatal; it logs a warning and lets the mount gate decide.
  That is intentional: a partial drain that still leaves zero mounts is harmless.
- The mount gate has a blind spot that `--ups` inherits: `ceph_mounts_on_node`
  swallows `talosctl` failures (`2>/dev/null || true`), so a node that is
  unreachable or already wedged reads as *clean*. The gate proves "no mounts
  visible", not "no mounts". The budget bounds the damage; it does not detect it.
