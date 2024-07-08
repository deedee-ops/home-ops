#!/usr/bin/env sh

mkdir -p /dest/acme-sh || true
mkdir -p /dest/borgmatic/borgmatic.d || true
mkdir -p /dest/borgmatic/config || true
mkdir -p /dest/snmp-exporter || true

cp /src/borgmatic-homelab.yaml /dest/borgmatic/borgmatic.d/homelab.yaml
cp /src/borgmatic-private.yaml /dest/borgmatic/borgmatic.d/private.yaml
cp /src/snmp-exporter-config.yaml /dest/snmp-exporter/snmp.yml

cp /src/docker-compose.yaml /dest/docker-compose.yml

trap : TERM INT; sleep infinity & wait
