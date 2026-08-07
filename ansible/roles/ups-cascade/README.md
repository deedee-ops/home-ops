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
on roughly half the load. The per-device split is an estimate — only the 189W
total is measured. **Treat every threshold here as provisional until the first
real discharge curve lands in the event log.**

Triggering on time-on-battery rather than a charge threshold is deliberate. A
14-minute UPS is not a ride-through device. Waiting for, say, 50% charge would
consume half the runway before the cascade even starts, and the cascade needs
most of it.

## State machine

```
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
        ▼                          talos_nodes_down | talos_nodes_down_timeout
NAS     ssh truenas_admin@nas.internal 'sudo midclt call system.shutdown'
        │    poll TCP 22 until it refuses, or 300s
        ▼                          nas_begin → nas_down | nas_timeout
HANDOFF                            handoff
        │  The daemon stops here permanently and only samples telemetry.
        │  ~55W left: switch, APs and ISP router stay up for another 10+ min.
        ▼
  upsmon LB (battery.runtime.low = 300) → FSD
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

`battery.runtime.low` is load-aware, which makes one threshold correct in both
situations. At full load (cascade wedged, everything still running) 300s of
runtime arrives early enough to still act. At ~55W (cascade succeeded) the same
300s lands much later in absolute charge terms, which is what keeps the network
alive. `battery.charge.low` stays at 0 — this UPS reports charge coarsely and
`device.mfr`/`battery.mfr.date`/`output.voltage` all return visibly wrong values,
so runtime is the only signal worth gating on.

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

It waits for all three nodes `Ready`, **then for all Ceph PGs to report an
`active` state**, and only then uncordons. The Ceph gate is not in the original
manual procedure but releasing ~183 pods onto a cluster whose RBD/CephFS is not
yet serving produces a CrashLoop stampede. On timeout it logs `recover_timeout`
and leaves the marker set rather than retrying blindly.

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

1. **Killpower is actually wired.** `upsmon` must write `POWERDOWNFLAG` and a
   late systemd shutdown unit must run `upsdrvctl shutdown`. If it is not hooked
   up the bank is never cut, `shutdown.return` never happens, and nothing comes
   back when mains returns. The last step of the whole design depends on it.
2. `upsc server-room-rack driver.flag.allow_killpower` reads `1`. The `ups.conf`
   syntax for driver flags is worth confirming against the running driver rather
   than trusting the template.
3. **BIOS "power on after AC loss"** on all three Talos nodes *and* the NAS. A
   flawless shutdown that needs four power buttons pressed is a poor outcome.
4. The NAS accepts the key and the sudo rule:
   `sudo -u root ssh -i /var/lib/ups-cascade/.ssh/id_ed25519 truenas_admin@nas.internal 'sudo midclt call system.shutdown --help'`
5. `systemctl start ups-cascade-recover` with no marker set logs
   `recover_skipped` and exits 0.
6. Run once with `ups_cascade_dry_run: true` and read the resulting log.
