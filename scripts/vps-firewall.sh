#!/usr/bin/env bash
#
# install.sh — restrict inbound ports to a single ASN's announced prefixes (Ubuntu).
#
#   * fail-closed: if prefixes can't be fetched, ports stay CLOSED, never open.
#   * always enforced: rules are (re)installed at every boot BEFORE the network
#     comes up, refreshed on a timer, and persisted via netfilter-persistent.
#   * multi-port: set PORTS to any space-separated list.
#
# Usage:
#   sudo ./install.sh                        # defaults: ASN=16342 PORTS="80 443"
#   sudo ASN=16342 PORTS="80 443 8443" ./install.sh
#
set -euo pipefail

ASN="${ASN:-16342}"
PORTS="${PORTS:-80 443}"
PROTO="${PROTO:-tcp}"

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }

echo ">> installing dependencies"
# autosave=false: the worker manages saves itself; preseed avoids the debconf prompt.
echo "iptables-persistent iptables-persistent/autosave_v4 boolean false" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean false" | debconf-set-selections
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  iptables ipset curl jq netfilter-persistent iptables-persistent >/dev/null

install -d -m 0755 /etc/asn-firewall /var/lib/asn-firewall

# --- config ----------------------------------------------------------------
cat > /etc/asn-firewall/config <<EOF
# Edit then: systemctl restart asn-firewall-refresh.service
ASN=${ASN}
PORTS="${PORTS}"
PROTO=${PROTO}
EOF
echo ">> config: ASN=${ASN} PORTS=\"${PORTS}\" PROTO=${PROTO}"

# --- worker ----------------------------------------------------------------
cat > /usr/local/sbin/asn-firewall.sh <<'WORKER'
#!/usr/bin/env bash
# Managed by install.sh — restrict PORTS to an ASN's prefixes. Fail-closed.
set -euo pipefail

CONFIG=/etc/asn-firewall/config
STATE=/var/lib/asn-firewall
CHAIN="ASN-FW"; NEWCHAIN="ASN-FW-n"
log(){ echo "[asn-firewall] $*"; }

[ -r "$CONFIG" ] || { log "missing $CONFIG"; exit 1; }
# shellcheck disable=SC1090
. "$CONFIG"
: "${ASN:?ASN not set}"; : "${PORTS:?PORTS not set}"; PROTO="${PROTO:-tcp}"
SET4="asn${ASN}_v4"; SET6="asn${ASN}_v6"
install -d -m 0755 "$STATE"

ensure_sets(){
  ipset create "$SET4" hash:net family inet  -exist
  ipset create "$SET6" hash:net family inet6 -exist
}

# fail-closed: with no saved data the sets stay empty => everything dropped.
restore_sets(){
  [ -f "$STATE/$SET4.save" ] && ipset restore -exist < "$STATE/$SET4.save" || true
  [ -f "$STATE/$SET6.save" ] && ipset restore -exist < "$STATE/$SET6.save" || true
}

fetch_sets(){
  local url="https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${ASN}" json p
  if ! json="$(curl -fsS --max-time 30 "$url")"; then
    log "fetch failed — keeping current prefixes, rules stay enforced"; return 1
  fi
  local prefixes; mapfile -t prefixes < <(jq -r '.data.prefixes[].prefix' <<<"$json" 2>/dev/null || true)
  [ "${#prefixes[@]}" -gt 0 ] || { log "no prefixes parsed — keeping current prefixes"; return 1; }

  ipset create "${SET4}_t" hash:net family inet  -exist; ipset flush "${SET4}_t"
  ipset create "${SET6}_t" hash:net family inet6 -exist; ipset flush "${SET6}_t"
  for p in "${prefixes[@]}"; do
    case "$p" in *:*) ipset add "${SET6}_t" "$p" -exist ;; *) ipset add "${SET4}_t" "$p" -exist ;; esac
  done
  ipset swap "${SET4}_t" "$SET4"; ipset destroy "${SET4}_t"
  ipset swap "${SET6}_t" "$SET6"; ipset destroy "${SET6}_t"
  ipset save "$SET4" > "$STATE/$SET4.save"
  ipset save "$SET6" > "$STATE/$SET6.save"
  log "loaded ${#prefixes[@]} prefixes for AS${ASN}"
}

# Build rules in a NEW chain, point INPUT at it, THEN retire the old one — no gap.
install_chain(){
  local ipt="$1" set="$2" port
  $ipt -N "$NEWCHAIN" 2>/dev/null || $ipt -F "$NEWCHAIN"
  for port in $PORTS; do
    $ipt -A "$NEWCHAIN" -p "$PROTO" --dport "$port" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    $ipt -A "$NEWCHAIN" -p "$PROTO" --dport "$port" -m set --match-set "$set" src -j ACCEPT
    $ipt -A "$NEWCHAIN" -p "$PROTO" --dport "$port" -j DROP
  done
  $ipt -I INPUT 1 -j "$NEWCHAIN"
  while $ipt -D INPUT -j "$CHAIN" 2>/dev/null; do :; done
  $ipt -F "$CHAIN" 2>/dev/null || true
  $ipt -X "$CHAIN" 2>/dev/null || true
  $ipt -E "$NEWCHAIN" "$CHAIN"   # rename updates the INPUT jump reference
}

install_rules(){ install_chain iptables "$SET4"; install_chain ip6tables "$SET6"; }

# Second persistence layer: write /etc/iptables/rules.v{4,6} for netfilter-persistent.
persist_rules(){ netfilter-persistent save >/dev/null 2>&1 || true; }

case "${1:-refresh}" in
  boot)    ensure_sets; restore_sets; install_rules; persist_rules
           log "boot: firewall enforced (fail-closed until first refresh)" ;;
  refresh) ensure_sets; fetch_sets || true; install_rules; persist_rules ;;
  status)  ipset list "$SET4" -terse; ipset list "$SET6" -terse
           iptables  -L "$CHAIN" -n -v 2>/dev/null || echo "v4 chain not present"
           ip6tables -L "$CHAIN" -n -v 2>/dev/null || echo "v6 chain not present" ;;
  *)       log "usage: $0 {boot|refresh|status}"; exit 1 ;;
esac
WORKER
chmod 0755 /usr/local/sbin/asn-firewall.sh
echo ">> wrote /usr/local/sbin/asn-firewall.sh"

# --- systemd units ---------------------------------------------------------
# boot: enforce rules early, before the network is up (fail-closed).
cat > /etc/systemd/system/asn-firewall-boot.service <<'EOF'
[Unit]
Description=ASN firewall (enforce rules at boot, fail-closed)
DefaultDependencies=no
After=local-fs.target
Wants=network-pre.target
Before=network-pre.target shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/asn-firewall.sh boot

[Install]
WantedBy=sysinit.target
EOF

# refresh: pull latest prefixes periodically.
cat > /etc/systemd/system/asn-firewall-refresh.service <<'EOF'
[Unit]
Description=ASN firewall refresh (fetch prefixes, reapply)
Wants=network-online.target
After=network-online.target asn-firewall-boot.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/asn-firewall.sh refresh
EOF

cat > /etc/systemd/system/asn-firewall-refresh.timer <<'EOF'
[Unit]
Description=Refresh ASN firewall prefixes

[Timer]
OnBootSec=2min
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

# netfilter-persistent restores rules that reference our ipsets, so order it after
# the boot service that creates those sets.
install -d -m 0755 /etc/systemd/system/netfilter-persistent.service.d
cat > /etc/systemd/system/netfilter-persistent.service.d/order-after-asn.conf <<'EOF'
[Unit]
After=asn-firewall-boot.service
Wants=asn-firewall-boot.service
EOF
echo ">> wrote systemd units"

# --- activate --------------------------------------------------------------
systemctl daemon-reload
systemctl enable --now asn-firewall-boot.service
systemctl enable --now asn-firewall-refresh.timer
systemctl enable netfilter-persistent.service >/dev/null 2>&1 || true
systemctl start asn-firewall-refresh.service || true   # populate + save now

echo
echo ">> DONE. Ports [${PORTS}] restricted to AS${ASN}."
echo "   status:      /usr/local/sbin/asn-firewall.sh status"
echo "   reconfigure: edit /etc/asn-firewall/config && systemctl restart asn-firewall-refresh.service"
