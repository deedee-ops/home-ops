# Ansible

Provisioning for plain (non-Talos) machines — currently a single VPS. Creates the
unprivileged user, installs Docker and its compose stacks, and restricts the public
ports to a set of ASNs.

## Usage

```sh
cd ansible
export ANSIBLE_USER_PASSWORD='...'    # login + sudo password for the unprivileged user
export ANSIBLE_VAULT_PASSWORD='...'   # unlocks inventory/group_vars/vps/vault.yaml

ansible-playbook site.yaml -e vps_host=1.2.3.4
ansible-playbook site.yaml -e vps_host=1.2.3.4 --check --diff   # dry run
```

`vps_host` has no default and must be passed. The control node needs the
`community.docker` collection (bundled with `pkgs.ansible`, otherwise
`ansible-galaxy collection install -r requirements.yaml`) and `passlib`, which
`password_hash` requires on Python 3.13+.

## Inventory

Per-host settings live in `inventory/hosts.yaml`, shared ones in
`inventory/group_vars/vps/`. Anything without a default fails the run when missing,
rather than silently provisioning something half-configured.

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
