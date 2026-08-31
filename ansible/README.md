# Ansible

Provisioning for plain (non-Talos) machines: the `vps` group (`mandark`) and the
`nut` group (`nutpi`). The VPS gets the unprivileged user, a swapfile, Docker and its
compose stacks, and a public-port allowlist by ASN. The Pi owns the UPS over USB and
orchestrates the ordered shutdown of the rest of the homelab.

## Usage

```sh
cd ansible
export ANSIBLE_USER_PASSWORD='...'    # login + sudo password for the unprivileged user
export ANSIBLE_VAULT_PASSWORD='...'   # unlocks inventory/group_vars/*/vault.yaml

ansible-playbook site.yaml -e vps_host=1.2.3.4                  # vps group
ansible-playbook site.yaml -e vps_host=1.2.3.4 --check --diff   # dry run

export VAULT_TOKEN='...'                                        # OpenBao, nut group only
ansible-playbook site.yaml --limit nut
```

`vps_host` has no default and must be passed for the `vps` plays; `--limit nut`
skips them, so it is not needed there. The `nut` group additionally needs
`VAULT_TOKEN`, because `ups-cascade` pulls the cluster credentials from OpenBao
at provision time.

The control node needs the `community.docker` collection (bundled with
`pkgs.ansible`, otherwise `ansible-galaxy collection install -r
requirements.yaml`), `passlib`, which `password_hash` requires on Python 3.13+,
and the `bao` CLI.

## Inventory

Per-host settings live in `inventory/hosts.yaml`, shared ones in
`inventory/group_vars/<group>/`. Anything without a default fails the run when
missing, rather than silently provisioning something half-configured.

| Variable | Default | Purpose |
| --- | --- | --- |
| `vps_host` | — | Address to connect to |
| `vps_root_domain` | — | Hostnames and the wildcard certificate derive from it |
| `vps_authorized_keys` | — | Authoritative content of the user's `authorized_keys` |
| `docker_compose_stacks` | `[]` | Directory names under `../docker` to deploy |
| `vps_user` | `ajgon` | Unprivileged user to create and connect as |
| `vps_root_user` | `root` | Bootstrap user, used only until `vps_user` exists |
| `vps_port` | `22` | SSH port |

## Connection user

`site.yaml` opens with a key-based `ssh` probe as `vps_user`. If it answers, the play
connects as that user and escalates with `sudo`; if it does not — a fresh box, or one
where the key is not installed yet — it falls back to `vps_root_user` and skips
escalation, since a minimal image may not even have `sudo`. The same command therefore
works on day zero and on every run after it.

The `user` role switches the live connection to the unprivileged user as soon as the
keys are in place, so everything after that point, including the sshd lockdown, runs
through `sudo` and proves it works.

## Vault

Stack secrets live in `inventory/group_vars/vps/vault.yaml`, encrypted with
ansible-vault. `ansible.cfg` points `vault_password_file` at `vault-pass.sh`, which is
executable, so ansible runs it and takes its stdout as the password. Ansible has no
environment variable for the password itself — only `ANSIBLE_VAULT_PASSWORD_FILE`, a
path — so the script bridges `$ANSIBLE_VAULT_PASSWORD`. With the variable unset every
command fails loudly instead of trying an empty password.

```sh
ansible-vault view inventory/group_vars/vps/vault.yaml
ansible-vault edit inventory/group_vars/vps/vault.yaml   # needs $EDITOR; vi is the default
```

Keys are prefixed `vault_` and mapped to their real names in `group_vars/vps/main.yaml`,
so you can see which secret feeds what without decrypting anything.

Changing the password: the old one comes from the environment, the new one has to be a
file, so chain it — a half-applied rekey leaves the file undecryptable.

```sh
printf '%s\n' 'newpass' > /tmp/np && chmod 600 /tmp/np \
  && ansible-vault rekey --new-vault-password-file /tmp/np inventory/group_vars/vps/vault.yaml \
  && export ANSIBLE_VAULT_PASSWORD=newpass && rm -f /tmp/np
```

## Roles

### user

Creates the user, sets its password from `$ANSIBLE_USER_PASSWORD` (hashed on the control
node with a salt derived from the user name, so re-runs are idempotent), grants sudo that
**requires that password** via `/etc/sudoers.d/<name>`, and writes `authorized_keys`.

Then it hardens sshd through a `/etc/ssh/sshd_config.d/` drop-in — `PermitRootLogin no`,
`PasswordAuthentication no` — and reloads rather than restarts, so live sessions survive.
Hardening refuses to run with no authorized key, which would lock everyone out.

| Variable | Default | Purpose |
| --- | --- | --- |
| `user_password` | — | From `$ANSIBLE_USER_PASSWORD` |
| `user_authorized_keys` | `[]` | Authoritative — keys not listed are removed |
| `user_extra_groups` | `[]` | Appended, never replaces existing membership |
| `user_shell` | `/bin/bash` | Login shell |
| `user_harden_ssh` | `true` | Write the sshd drop-in |

The user is deliberately **not** in the `docker` group: socket access to a root daemon is
root, which would make the sudo password decorative. Use `sudo docker`, or set
`docker_users` if you disagree.

### swapfile

Gives the VPS headroom beyond its physical RAM: allocates `/swapfile`, formats it,
activates it and writes the `/etc/fstab` entry so it comes back after a reboot. The path
is a literal, not a variable — one swapfile per host at the conventional location is the
whole feature.

Changing `swapfile_size` rebuilds the file, because the kernel pins the extent map of an
area in use and it cannot be resized in place. The `swapoff` that precedes the rebuild
fails if the swapped-out pages no longer fit in RAM; that failure is deliberate, since the
alternative is the OOM killer picking a victim mid-play.

The role refuses to run on a btrfs or zfs root: `fallocate` produces a file those
filesystems cannot serve as swap (btrfs needs nocow and no compression, zfs deadlocks
under memory pressure), and the failure would otherwise surface as an obscure `swapon`
error rather than a clear one.

| Variable | Default | Purpose |
| --- | --- | --- |
| `swapfile_size` | `1G` | Anything `human_to_bytes` accepts; a change rebuilds the file |

### docker

Installs `docker-ce`, `containerd.io` and the compose and buildx plugins, writes
`/etc/docker/daemon.json` (validated with `dockerd --validate`) and enables the service.
Everything is distribution agnostic except the repository setup, which is dispatched on
`ansible_facts['os_family']` to `tasks/repository/<family>.yaml`; adding `RedHat.yaml` is
enough to support that family.

Each name in `docker_compose_stacks` maps to a directory under `../docker`. The whole
directory is copied to `/opt/stacks/<stack>/` — config files included, since the compose
files mount them — then a `.env` is written from `docker_compose_env` merged with
`docker_compose_secret_env` (mode `0600`, `no_log`), and the stack is brought up. Networks
in `docker_compose_networks` are created first: the stacks declare them `external: true`,
so compose will not create them and `up` would fail.

| Variable | Default | Purpose |
| --- | --- | --- |
| `docker_compose_stacks` | `[]` | Directories under `../docker`; empty skips the whole step |
| `docker_compose_dir` | `/opt/stacks` | Where projects are synced to |
| `docker_compose_env` | `DATA_DOCKER_DIR`, `ROOT_DOMAIN` | Non-secret compose variables |
| `docker_compose_secret_env` | `{}` | Merged into `.env`, kept out of logs |
| `docker_compose_networks` | `internal` | Created if missing before any stack starts |
| `docker_users` | `[]` | Users added to the `docker` group |
| `docker_daemon_config` | log rotation, `live-restore` | `/etc/docker/daemon.json`; `{}` skips |

### asn_firewall

Restricts ports to the prefixes announced by given ASNs, fetched from RIPEstat into one
ipset per ASN. Fail-closed: if the fetch fails the sets keep their last contents — empty
on a fresh box — so ports stay closed rather than open. A boot unit enforces the rules
before the network comes up, a timer refreshes prefixes hourly, and `netfilter-persistent`
keeps them across reboots. Ports that are not listed are untouched.

```yaml
asn_firewall_rules:
  - asn: 123
    ports: [5, 6]
  - asn: 456
    ports: [6, 7]
    proto: udp   # optional, defaults to tcp
```

A port listed under several ASNs accepts traffic from all of them: the chain is built per
protocol/port, with every matching ASN's accept emitted before that port's single `DROP`.
`proto` is part of the key, so `tcp/6` and `udp/6` stay independent. Sets belonging to
ASNs you remove are destroyed on the next refresh.

The rules are installed twice, because a port can be served two ways:

- **`INPUT`** (chain `ASN-FW`) — services listening on the host. Matched on `--dport`,
  allowed traffic is accepted.
- **`DOCKER-USER`** (chain `ASN-FW-FWD`) — published container ports. That traffic is
  DNAT'd and forwarded, so it never reaches `INPUT`. Matched on
  `conntrack --ctorigdstport`, because by then the packet carries the container's port
  rather than the published one. Allowed traffic only returns: an accept here would end
  the whole `FORWARD` traversal and skip docker's own isolation rules.

The `DOCKER-USER` half is scoped to the WAN interface, so container egress and
container-to-container traffic crossing the same chain are not mistaken for inbound
connections. Docker never flushes `DOCKER-USER`, so the rules survive a docker restart.

Everything in `asn_firewall_trusted_sources` returns from both chains before any `DROP`
can match, so loopback, LAN and docker bridge traffic is never filtered.

| Variable | Default | Purpose |
| --- | --- | --- |
| `asn_firewall_rules` | AS16342 → 80, 443 tcp | ASN → ports pairs |
| `asn_firewall_trusted_sources` | loopback, RFC1918, link-local, ULA | Never filtered |
| `asn_firewall_wan_interface` | detected from the default route | Scopes the `DOCKER-USER` rules |
| `asn_firewall_refresh_calendar` | `hourly` | systemd `OnCalendar` for refreshes |

Inspect the live state on the host with `/usr/local/sbin/asn-firewall.sh status`. Note
that `netfilter-persistent save` snapshots all live rules, docker's included.

### nut

Installs Network UPS Tools, points the `usbhid-ups` driver at the PowerWalker VI 750 R1U
over USB, and runs `upsmon`. The `nut` group (`nutpi`) runs in `netserver` mode: it owns
the UPS and serves its status on the LAN so other machines can attach as `secondary`
clients.

The UPS itself is not parameterised — `ups.conf.j2` names it `server-room-rack` and pins
the `0764:0601` USB IDs, `upsd.conf.j2` listens on `0.0.0.0:3493`, and `upsd.users.j2`
declares a fixed three-account block. There is one UPS and it is not moving; a variable
per field would only be a second place to edit.

Two knobs are genuinely tunable, and both are `override.<key>` lines the driver applies
on top of what the hardware reports:

This role sets **no** LB thresholds, deliberately. On this UPS the `LB` flag comes only
from the device's own HID status bits, never from `battery.charge.low` or
`battery.runtime.low`, and the firmware rejects any attempt to write them. `override.` in
`ups.conf` is worse than useless — it changes the reported value only, and makes the
variable immutable, blocking the write that might have worked. The cascade therefore picks
its own moment to trigger FSD; see the `ups-cascade` README.

`SHUTDOWNCMD` and `POWERDOWNFLAG` are hardcoded in `upsmon.conf.j2`, pointing at
`/usr/local/sbin/ups-cascade-shutdown` and `/etc/killpower`. The wrapper is deployed by
`ups-cascade`; the two roles have to agree on those paths, so they are literals in both
rather than a variable in one.

The three `upsd` accounts — `admin` (SET + instcmds), `upsmon` (primary), `secondary` —
take their passwords from `inventory/group_vars/nut/vault.yaml` (ansible-vault,
`vault_`-prefixed and mapped in `group_vars/nut/main.yaml`) exactly like the vps group —
nothing in git. The role asserts `nut_monitor_password` is non-empty before doing anything.

| Variable | Default | Purpose |
| --- | --- | --- |
| `nut_mode` | `standalone` | `standalone`, or `netserver` to serve secondaries |
| `nut_admin_password` | — | upsrw/upscmd admin, from `vault_nut_admin_password` |
| `nut_monitor_password` | — | primary upsmon, from `vault_nut_primary_password` |
| `nut_secondary_password` | — | secondary clients, from `vault_nut_secondary_password` |

Who actually attaches as a secondary:

- **The NAS** — TrueNAS' own UPS service, configured by hand in its UI, set to shut down
  on low battery. It is a dead-man backstop only; in the normal case `ups-cascade` shuts
  it down first, by SSH, well before `LB`.
- **The Talos nodes** — *nothing*. The `siderolabs/nut-client` extension was evaluated and
  rejected: its `SHUTDOWNCMD` is locked to `/sbin/poweroff`, which triggers Talos' own
  uncustomisable simultaneous drain on all three nodes and deadlocks Ceph exactly as
  `scripts/CLAUDE.talos-shutdown.md` documents. They are driven from the Pi instead.

### ups-cascade

Runs on the Pi alongside `nut`. Polls `upsc`, and when the UPS has been on battery past a
ride-through window, shuts the homelab down in dependency order — Talos, then the NAS —
then hands back to stock `upsmon` for the Pi's own shutdown and the UPS power cut.

Ordering is not a preference. The Talos nodes mount 28 NFS shares from the NAS, so the NAS
cannot go first; the switch carries all NUT traffic and the Pi coordinates everything, so
the Pi goes last. The four UPS outlets are a single non-switchable bank, so the final power
cut takes the switch and the ISP router with it.

It ships a systemd daemon (`ups-cascade.service`), a boot-recovery unit
(`ups-cascade-recover.service`) that uncordons the nodes once Ceph is serving again, the
`upsmon` `SHUTDOWNCMD` wrapper, and a JSON Lines event log at
`/var/lib/ups-cascade/events.jsonl` that doubles as the battery calibration dataset. It
also deploys `scripts/talos-shutdown.sh`, which it invokes with `--ups`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `ups_cascade_ride_through` | `60` | Seconds on battery before the cascade starts |
| `ups_cascade_ol_stable` | `30` | Seconds of restored mains required to abort |
| `ups_cascade_talos_deadline` | `420` | Hard cap on the Talos phase |
| `ups_cascade_nodes_down_deadline` | `120` | Wait for nodes to stop answering on `:50000` |
| `ups_cascade_nas_deadline` | `300` | Wait for the NAS to stop answering on `:22` |
| `ups_cascade_abort_cooldown` | `900` | After an abort, re-triggers run straight through |
| `ups_cascade_recover_deadline` | `1200` | Boot recovery gives up after this |
| `ups_cascade_dry_run` | `false` | Run the state machine, stub every destructive call |
| `ups_cascade_nodes` | blossom/bubbles/buttercup | Name → address, used when the API is down |
| `ups_cascade_nas_user` | `truenas_admin` | SSH account on the NAS |
| `ups_cascade_nas_shutdown_cmd` | `sudo midclt call system.shutdown` | Run over SSH |
| `ups_cascade_nas_private_key` | — | SSH key for the NAS, from `vault_ups_cascade_nas_private_key` |

Paths (`/var/lib/ups-cascade`, `/usr/local/lib/ups-cascade`, `/etc/ups-cascade`) and the
Ceph namespace are constants in the tasks and in `ups_cascade.py`, not variables.

Every threshold above is provisional until a real discharge curve exists.
**`ansible/roles/ups-cascade/README.md` is the design document** — the power topology, the
battery budget, why the Pi's shutdown is left to stock `upsmon`, why aborting stops at the
point of no return, and the list of things that fail silently and must be verified on the
host after the first apply.

```sh
export ANSIBLE_VAULT_PASSWORD='...'   # unlocks inventory/group_vars/nut/vault.yaml
export VAULT_TOKEN='...'              # OpenBao, for the Talos credentials
ansible-playbook site.yaml --limit nut
```

## Linting

`ansible-lint` runs as a pre-commit hook whenever anything under `ansible/` changes,
scoped to this directory because a repo-wide run trips over the kubernetes manifests.
`.ansible-lint` selects the `production` profile and skips the `yaml` rule, which the
repo-wide `yamllint` hook already covers; `.yamllint` exists only to keep ansible-lint off
the repo-wide config, which it rejects.

```sh
# from the repo root
ansible-lint -c ansible/.ansible-lint --yamllint-file ansible/.yamllint ansible
```
