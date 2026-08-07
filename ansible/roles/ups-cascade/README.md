# `ups-cascade`

Ordered shutdown of the homelab when the UPS goes on battery, driven from the NUT
primary (`nutpi`). Companion to the `nut` role, which owns the NUT server config
itself. Designed 2026-08-07; this file is the reasoning, `files/ups_cascade.py` is
the implementation.

## The hardware constraint everything follows from

PowerWalker VI 750 R1U, four outlets:

| Outlet | Load |
| --- | --- |
| 1 | UniFi switch (PoE for the whole network stack), NAS (TrueNAS) |
| 2 | `blossom` / `bubbles` / `buttercup` (Talos) |
| 3 | `nutpi` (NUT primary) |
| 4 | ISP router (no configuration possible) |

**The outlets are not individually switchable.** The driver exposes no `outlet.*`
variables and `LIST CMD` has only global `load.off` / `load.on` /
`shutdown.return`. Electrically it is one bank; the four sockets are physical
convenience only. Sequencing therefore has to happen in software timing, and any
power cut is all-or-nothing.

Ordering is forced by two dependencies:

- Talos mounts **28 NFS shares from `nas.internal`**. If the NAS goes first those
  mounts hang and the drain stalls. NAS must follow Talos.
- The switch carries all NUT traffic and the Pi coordinates everything, so the Pi
  cuts the bank last, killing itself, the switch and the router together.

## Budget

`battery.runtime` reads 840s at 42% of 450W — roughly **189W draw, 44Wh usable**.
Worst case, every phase pinned to its deadline:

| Phase | Duration | Load | Cumulative |
| --- | --- | --- | --- |
| ride-through | 60s | 189W | 7% |
| Talos cascade | 420s | 189W | 57% |
| nodes powering off | 120s | 189W | 71% |
| NAS shutdown | 300s | ~100W | 90% |
| Pi + killpower | ~60s | ~55W | 92% |

It fits because the expensive phase is also the first one; everything after runs
on roughly half the load.

### Measured, 2026-08-09

Three real discharges agree: **~6.3%/min at full load**, so ~16 minutes total —
slightly better than the estimate above. Load reads 40–42% with everything up and
drops to 27–28% once the NAS is down, i.e. the NAS alone is ~67W. Phase timings
from the first full run:

| Phase | Elapsed | Charge spent |
| --- | --- | --- |
| ride-through | 60s | 6% |
| cordon | 15s | 3% |
| drain | 188s — **hit the 180s cap** | 19% |
| mount gate | <1s | 0% |
| shutdown stagger (3 × 15s) | 46s | 5% |

The drain is by far the most expensive phase. It was briefly raised 180 → 240 on
the assumption it needed longer; a second run disproved that and it is back at
180. The drain is **bimodal**: 139 of 142 pods terminate in ~50s and the same
three never do (`flux-system/helm-controller`, `system-upgrade/tuppr` ×2), so the
timeout is only ever spent waiting for pods that were never going to finish.
Lowering it further is tempting but not yet justified — the bulk phase took ~50s
in one run and closer to ~170s in another, and the cause of that spread is
unknown. See `PROMPT.md`.

Triggering on time-on-battery rather than a charge threshold is deliberate. A
14-minute UPS is not a ride-through device. Waiting for, say, 50% charge would
consume half the runway before the cascade even starts, and the cascade needs
most of it.

## State machine

```text
IDLE (OL)
  │ ups.status → OB
  ▼
RIDE_THROUGH ──────────── mains_lost
  ├─ OL returns <60s ──── mains_restored (blip) ──→ IDLE
  ├─ within abort cooldown → ride_through_skipped, straight to TALOS,
  │                          abort disabled for this run
  └─ 60s elapsed ──────── ride_through_expired
       ▼
TALOS   talos-shutdown.sh --ups   (UPS_DEADLINE 420s, daemon backstop +60s)
  │       talos_begin → talos_preflight_ok → talos_cordoned → talos_drained
  │                   → talos_mounts_clear
  ├─ OL stable 30s, BEFORE point of no return
  │     └─→ cascade_aborted: SIGTERM the process group, kubectl uncordon ×3,
  │         arm a 15-minute cooldown ──→ IDLE
  └─ talos_point_of_no_return
        ▼
     ═══ COMMITTED — no abort from here ═══
        ▼
NODES_DOWN   poll TCP 50000 on .21/.22/.23 until all refuse, or 120s
        │  still answering at the deadline → retry talosctl shutdown from here,
        │  where the per-node exit status is logged, then wait one more window
        ▼   talos_nodes_down | talos_nodes_down_timeout → talos_nodes_down_giving_up
NAS     ssh truenas_admin@nas.internal 'midclt call -j system.shutdown <reason>'
        │    poll TCP 22 until it refuses, or 300s
        ▼                          nas_begin → nas_down | nas_timeout
HANDOFF                            handoff
        │  The daemon stops here permanently and only samples telemetry.
        │  ~55W left: switch, APs and ISP router stay up for another 10+ min.
        ▼
  orchestrator: battery.charge <= 20 → `upsmon -c fsd`
        └─→ SHUTDOWNCMD = /usr/local/sbin/ups-cascade-shutdown
                 logs pi_shutdown, sync, /sbin/shutdown -h +0
              → POWERDOWNFLAG → upsdrvctl shutdown
              → bank cut after ups.delay.shutdown (20s)

  mains returns → shutdown.return re-powers the bank (ups.delay.start 30s)
       → Pi boots → ups-cascade-recover.service
```

### Why the Pi's own shutdown is left to stock `upsmon`

The orchestrator deliberately does nothing in `HANDOFF`. If it also owned the
final trigger there would be two decision-makers, and the failure mode is
severe: `upsmon` hitting LB mid-drain would FSD, shut the Pi down and kill the
bank **with Ceph mounts live** — precisely the wedge the whole design exists to
avoid.

The orchestrator does own **when**, though, and that is a correction to the
original design. It first left the trigger entirely to `upsmon`'s LB. That does
not work on this hardware, established over two runs on 2026-08-09:

- `LB` is set only from the device's own HID status bits —
  `usbhid-ups.c:1922` sets it from `LOWBATT | TIMELIMITEXP | SHUTDOWNIMM` and
  never compares `battery.charge.low` or `battery.runtime.low`.
- This UPS trips it at `runtime <= 300`, and `battery.runtime` was measured as
  quantised to 60-second steps and **non-monotonic**, oscillating 240/300/360/420
  while charge fell smoothly. During a real cascade the `LB` flag appeared for a
  single 5-second sample and cleared again.
- The thresholds cannot be moved. `override.battery.*` in `ups.conf` changes only
  the reported value, and `main.c:298-302` marks overridden variables
  `ST_FLAG_IMMUTABLE`, which strips `ST_FLAG_RW` and *blocks* the write that might
  have worked. With the overrides removed, `upsrw -s battery.charge.low=95` and
  `battery.runtime.low=1000` both return `OK` and then revert — this firmware
  rejects both.

So the final trigger is gated on `battery.charge`, which is monotonic and well
behaved, at `ups_cascade_fsd_charge` (default 20). `upsmon` still performs every
part of the shutdown — FSD, `POWERDOWNFLAG`, `SHUTDOWNCMD`, killpower — we only
choose the moment. The device's own LB remains as a backstop if the orchestrator
never gets there.

This does not reintroduce the two-decision-makers problem described above,
because the trigger arms strictly after `handoff`: by then Talos and the NAS are
already down, so it cannot fire mid-drain.

### Why abort stops at the point of no return

With a 60s trigger, a 61-second blip starts a cascade, so mid-cascade mains
return is the common case rather than an edge case. Before the first
`talosctl shutdown` the only damage is a cordon and a drain: recovery is
`kubectl uncordon` and pods reschedule. After it, a half-powered-off cluster is
the wedge state, so the run must complete.

The 15-minute cooldown exists because a flapping grid would otherwise drain the
cluster repeatedly. A re-trigger inside the cooldown skips the ride-through and
disallows aborting — by then there is not enough battery left to keep gambling on
the power coming back.

## Event log

`/var/lib/ups-cascade/events.jsonl`, JSON Lines, one object per line, `fsync`ed
on every write and mirrored to the journal. Two record types:

```json
{"ts":"2026-08-07T21:14:03Z","type":"event","event":"mains_lost","phase":"ride_through","status":"OB DISCHRG","charge":100,"runtime":840,"load":42}
{"ts":"2026-08-07T21:14:08Z","type":"sample","phase":"ride_through","status":"OB DISCHRG","charge":98,"runtime":812,"load":42}
```

`sample` records are emitted every `poll_interval` whenever the phase is not
`IDLE`, so a full 14-minute discharge is about 170 lines. That is deliberate:
**the log doubles as the calibration dataset**, and after the first real outage
the discharge curve is available without staging a test.

```sh
jq -r 'select(.type=="event") | [.ts, .event, .charge, .runtime] | @tsv' events.jsonl
jq -r 'select(.type=="sample") | [.ts, .charge, .runtime, .load] | @csv' events.jsonl
```

Rotation is size-based with 24 generations kept — this is outage history worth
keeping for years, at a few KB per event.

## Boot recovery

`ups-cascade-recover.service` runs once at boot. It is gated on a marker in
`state.json` set at the point of no return and cleared only after a successful
uncordon, so it never touches nodes that were cordoned by hand for unrelated
maintenance.

**Nodes `Ready` is the only precondition.** It waits for that, uncordons, clears
the marker, and only then polls Ceph health for the log.

An earlier version gated the uncordon on Ceph being healthy first, to avoid
releasing ~183 pods onto storage that was not yet serving. That gate was
unsatisfiable and deadlocked on 2026-08-09. Two reasons, either sufficient:

- It read health by `kubectl exec` into `rook-ceph-tools`, which does not carry
  the `rook_cluster` label, so the drain deletes it — and it cannot be rescheduled
  while the nodes are cordoned.
- After a real power cycle every Ceph mon and OSD is gone too. They are
  Deployments, so their pods need scheduling, and **nothing schedules on a
  cordoned node**. Ceph cannot become healthy before the uncordon that the gate
  was blocking.

The original manual procedure was right: uncordon is the only required step. The
cold-start CrashLoop wave is noisy but self-healing, and it is unavoidable — the
storage is itself made of pods. Ceph health is now reported after the fact via the
`CephCluster` CR (no `exec`, no toolbox), purely so the log shows how long the
cold start took. `recover_ceph_timeout` is informational and does not fail the
unit.

## Fixed paths

These are constants, hardcoded in `tasks/main.yaml` and in `ups_cascade.py`
rather than templated. Nothing chooses between them, so parameterising them only
made two places to keep in sync:

| Path | Contents |
| --- | --- |
| `/var/lib/ups-cascade/` | `events.jsonl`, `state.json`, `kubeconfig`, `talosconfig`, `.ssh/` |
| `/usr/local/lib/ups-cascade/` | `ups_cascade.py`, `talos-shutdown.sh` |
| `/etc/ups-cascade/ups-cascade.env` | systemd `EnvironmentFile` |
| `/usr/local/sbin/ups-cascade-shutdown` | `upsmon` `SHUTDOWNCMD` wrapper |

The Ceph namespace (`rook-ceph`) is fixed for the same reason.

## The API VIP host route

`192.168.42.20` sits inside the Pi's own subnet, so the kernel treats it as
on-link and ARPs for it. Nothing answers: the VIP is a Cilium `LoadBalancer`
address advertised over BGP, and no host owns it at layer 2. `ip neigh` shows it
permanently `FAILED` and the packet never leaves the Pi. Without a fix the Pi
cannot reach the Kubernetes API at all, which takes out the Talos phase and boot
recovery both.

`ups-cascade-route.service` installs a `/32` with the **node addresses** as next
hops:

```sh
ip route replace 192.168.42.20/32 \
  nexthop via 192.168.42.21 nexthop via 192.168.42.22 nexthop via 192.168.42.23
```

The next hops come from `ups_cascade_nodes`, so they stay in step with the rest
of the role; `ups_cascade_api_vip` is the address itself.

### Why not via the default gateway

That was tried first (2026-08-08) and times out. `kubernetes/apps/kube-system/cilium/README.md`
has the UniFi FRR config, and it peers with the nodes:

```text
neighbor 192.168.42.21 peer-group k8s
neighbor 192.168.42.22 peer-group k8s
neighbor 192.168.42.23 peer-group k8s
```

So the gateway learns `192.168.42.20/32` with next hops on the *same* VLAN
interface the Pi is on. Routing Pi → gateway → node would need the gateway to
hairpin — receive on that interface and forward straight back out of it — which
UniFi drops. It is also a pointless detour to reach a node on the Pi's own L2
segment. Going straight to the nodes is exactly what the gateway would have done
on our behalf; Cilium's datapath handles the LB IP on any node with a local
backend, and `externalTrafficPolicy: Local` plus a `kube-apiserver` pod on every
control-plane node makes all three valid.

Verified: `curl -sk https://192.168.42.20:6443/version` returns `401` (reached
the apiserver, rejected for lack of credentials) with either a single node or all
three as next hops.

### The tradeoff

Static ECMP has **no liveness detection**. If a node is down, the flows hashed to
it blackhole rather than failing over, where a BGP-learned route would have been
withdrawn. This is tolerable here and deliberate: the Pi only needs the API during
the Talos phase, when all three nodes are still up, and during boot recovery,
which waits for all three `Ready` before doing anything. A failure degrades into
`force_shutdown_all`, which is safe. Do not "improve" this by pointing it at a
single node — that trades a third of the flows for all of them.

The unit alone is not sufficient. NetworkManager owns the link on Raspberry Pi OS
and flushes routes it does not manage whenever it reactivates a connection, so a
switch reboot or a cable flap would silently drop the route and only a reboot
would bring it back. A dispatcher script at
`/etc/NetworkManager/dispatcher.d/50-ups-cascade-route` re-asserts it on every
`up` and `dhcp4-change`. It is installed only if the dispatcher directory exists,
so hosts on dhcpcd or systemd-networkd get the unit and nothing else.

Both `ups-cascade.service` and `ups-cascade-recover.service` declare `Wants=` and
`After=` on the route unit, so neither can start against an unreachable API.

Note this affects the VIP only. The node addresses `192.168.42.21-23` that
`talosctl` uses are ordinary L2 hosts and must not be routed.

## Name the credentials explicitly

Every `kubectl` and `talosctl` invocation passes `--kubeconfig` / `--talosconfig`
rather than relying on the environment, and `preflight` aborts if either file is
unreadable. This is not belt-and-braces, it is a scar.

On 2026-08-09 a full Phase 7 run failed because `TALOSCONFIG` did not survive the
hop from systemd through the daemon into the shell script. `talosctl` fell back to
`$HOME/.talos/config`, systemd services have no `$HOME`, and every call died with
`failed to open config file "": $HOME is not defined`. Three nodes were told to
shut down and none did.

It was invisible for two reasons, both now fixed:

- `shutdown_nodes` ran every call under `|| true` and emitted
  `talos_shutdown_issued` unconditionally, so the log claimed success.
- `ceph_mounts_on_node` swallowed the same failure into an empty result, which the
  mount gate read as "no Ceph mounts". **The gate protecting the cluster from the
  documented Ceph deadlock was passing because the command was broken.** It now
  fails closed: an unreadable node counts as not-clear.

The general lesson, which cost three separate bugs in one run: **a zero exit
status from a command that only queues work proves nothing.** `talosctl shutdown`
behind `|| true`, `midclt call` without `-j`, and `talosctl mounts` failing into
silence all reported success while doing nothing. Where the design verifies
independently — polling apid for `nodes_down`, polling ssh for `nas_down` — it
caught the failure; where it trusted an exit code, it did not.

## Credentials

Three secrets reach the Pi at provision time and never at runtime:

- `TALOSCONFIG` and `KUBECONFIG` — pulled from OpenBao `deedee/talos`, mirroring
  the `envconsul`/`bao` pattern in `devenv.nix`. Requires `VAULT_TOKEN` in the
  environment; the role asserts on it.
- `ups_cascade_nas_private_key` — the private key authorised for
  `truenas_admin@nas.internal`. Stored as `vault_ups_cascade_nas_private_key` in
  `inventory/group_vars/nut/vault.yaml` and mapped to its real name in
  `group_vars/nut/main.yaml`, following the same `vault_`-prefix convention as
  the `nut` passwords. The role asserts it is set and writes it to
  `/var/lib/ups-cascade/.ssh/id_ed25519` (0600). The matching public key and the
  passwordless sudo rule for `midclt call system.shutdown` are configured on the
  TrueNAS side by hand.

The Pi therefore holds cluster-admin, Talos `os:admin` and NAS shutdown rights.
It is the most privileged host on the network, and that is the standing cost of
this design.

## Dry run

Set `ups_cascade_dry_run: true` (or `UPS_CASCADE_DRY_RUN=1`) and the full state
machine, all timing and all logging run unchanged, while the three destructive
steps are stubbed: `talos-shutdown.sh` is invoked with `--dry-run`, the NAS ssh is
skipped, and the phases that wait for something to die advance immediately
instead of burning their deadlines. Every skipped step is logged with
`reason=dry_run`.

This is the only way to exercise the thing without pulling the mains, which
matters for a path that runs at most a couple of times a year.

## What this role does not own

- **NUT server config** — `nut` role. Two settings there exist for this one:
  `allow_killpower = 1` (without it the Pi never cuts the bank and the UPS just
  runs flat) and `SHUTDOWNCMD` pointing at this role's wrapper.
- **TrueNAS** — configured by hand. Its native UPS service should be a NUT
  secondary against `nutpi` set to shut down **on low battery**, as a dead-man
  backstop for the case where the Pi itself is dead. It must not be set to
  "UPS goes on battery" with a timer: a fixed timer can fire while Talos is still
  draining, and the NFS dependency makes that actively harmful.
- **The Talos `nut-client` extension** — deliberately *not* used. It was
  evaluated and rejected: its `SHUTDOWNCMD` is locked to `/sbin/poweroff`, which
  calls `client.Shutdown()` without `force`, i.e. Talos' own uncustomisable
  simultaneous drain on all three nodes at once. That is verbatim the deadlock
  documented in `scripts/CLAUDE.talos-shutdown.md`. It would have cost a rolling
  cluster upgrade to gain a backstop that wedges.

## Verify after first apply

None of these can be checked from the repo, and each fails silently:

1. **`POWEROFF_WAIT` is set in `/etc/nut/nut.conf`.** The systemd shutdown hook
   (`/usr/lib/systemd/system-shutdown/nutshutdown`, shipped by `nut-server`)
   sources that file. Without the variable it commands the UPS off and then
   simply halts. If mains returns inside `ups.delay.shutdown` the UPS cancels the
   cut, and the Pi is left **powered but halted, with nothing to boot it** — the
   whole rack recovers except the machine that runs the cascade, and you only
   find out at the next outage. With it set, the hook sleeps: a real bank cut
   never returns from the sleep, and a cancelled one force-reboots the Pi back
   into service. The `nut` role writes it; `nut_poweroff_wait` is the knob.
2. **Killpower is actually wired.** `upsmon` must write `POWERDOWNFLAG` and
   `/usr/lib/systemd/system-shutdown/nutshutdown` must run `upsdrvctl shutdown`.
   If it is not hooked up the bank is never cut, `shutdown.return` never happens,
   and nothing comes back when mains returns.

   **Verified on hardware 2026-08-09**: unplugged, `upsmon -c fsd`, `ups.status`
   showed `FSD`, the Pi halted within seconds, the UPS cut the bank a few seconds
   later, and everything powered back on when mains was restored. Note this only
   works **on battery** — with mains present `shutdown.return` re-energises
   immediately, so testing it on line power proves nothing.
3. `ups.conf` contains **no** `override.battery.*` lines. They are not a way to
   set LB thresholds — they change only the reported value and make the variable
   immutable, blocking `upsrw`. `upsc server-room-rack battery.charge.low` should
   show the device's own value (0 here), and `LIST RW` should still include it.
   Note that any real `ups.conf` change needs a genuine restart of
   `nut-driver@server-room-rack`: `nut-driver-enumerator` only reconciles
   *sections*, so in-section edits never reach a running driver
   (networkupstools/nut#2410). The `nut` role's handler does this.

   Do **not** add `allow_killpower` to `ups.conf` — it was tried and removed on
   2026-08-08. `main()` unconditionally resets
   `dstate_setinfo("driver.flag.allow_killpower", "0")` *after* the config is
   parsed (drivers/main.c:2398 in v2.8.1), so it can never read `1`, and
   `main_arg()` skips flag vars when `reload_flag` is set so a reload cannot
   apply it either. It is also unnecessary: `upsdrvctl shutdown` runs the driver
   with `-k`, which dials the running instance over the socket protocol and
   sends `SET driver.flag.allow_killpower 1` followed by
   `INSTCMD driver.killpower` (main.c:1916-1943). The shutdown path arms the flag
   itself, so `upsc ... driver.flag.allow_killpower` reading `0` at rest is
   correct and expected.
4. **BIOS "power on after AC loss"** on all three Talos nodes *and* the NAS. A
   flawless shutdown that needs four power buttons pressed is a poor outcome.
   Confirmed working 2026-08-09: all four booted unattended after the bank was
   re-energised.
5. The NAS accepts the vaulted key and the sudo rule. Note `system.shutdown`
   takes a **mandatory reason** since TrueNAS 25.04, and plain `midclt call`
   returns a job id and exits 0 even when the job then fails validation — hence
   `-j` in `ups_cascade_nas_shutdown_cmd`.
6. `systemctl start ups-cascade-recover` with no marker set logs
   `recover_skipped` and exits 0.
7. Run once with `ups_cascade_dry_run: true` and read the resulting log.
