#!/usr/bin/env sh

mkdir -p /dest/acme-sh || true
mkdir -p /dest/borgmatic/borgmatic.d || true
mkdir -p /dest/borgmatic/config || true

cp /src/borgmatic-homelab.yaml /dest/borgmatic/borgmatic.d/homelab.yaml
cp /src/borgmatic-private.yaml /dest/borgmatic/borgmatic.d/private.yaml
cp /src/docker-compose.yaml /dest/docker-compose.yml

trap : TERM INT; sleep infinity & wait
