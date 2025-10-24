#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CONTEXT="$1"
TARGET_DIR="$2"

HOSTS_DIR="$(realpath "$SCRIPT_DIR/../docker/hosts")"
KOMODO_STACK_DIR="$(realpath "$SCRIPT_DIR/../docker/stacks/komodo")"
SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE:-/etc/age/keys.txt}

if test -z "$CONTEXT"; then
  echo "Error: context not given"
  exit 1
fi

if test -z "$TARGET_DIR"; then
  echo "Error: target dir not given"
  exit 1
fi

if ! test -d "$TARGET_DIR"; then
  echo "Error: target dir does not exist or not a directory"
  exit 1
fi

sops_cmd="sops"
if ! command -v sops &> /dev/null; then
  sops_cmd="docker run --rm -e SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE} -v ${SOPS_AGE_KEY_FILE}:${SOPS_AGE_KEY_FILE} -v ${HOSTS_DIR}:${HOSTS_DIR} ghcr.io/getsops/sops:v3.11.0-alpine"
fi

if ! test -f "$SOPS_AGE_KEY_FILE"; then
    echo "Error: missing age key file at $SOPS_AGE_KEY_FILE"
    exit 1
fi

# prepare compose files and envs for komodo
mkdir -p "$TARGET_DIR/stacks/komodo" "$TARGET_DIR/volumes/komodo"
cp "$KOMODO_STACK_DIR/"* "$TARGET_DIR/stacks/komodo/"

if test -f "$HOSTS_DIR/$CONTEXT/bootstrap/komodo.sops.env"; then
  $sops_cmd -d "$HOSTS_DIR/$CONTEXT/bootstrap/komodo.sops.env" > "$TARGET_DIR/stacks/komodo/override.env"
fi

if test -f "$HOSTS_DIR/$CONTEXT/bootstrap/config.sops.toml"; then
  $sops_cmd -d "$HOSTS_DIR/$CONTEXT/bootstrap/config.sops.toml" > "$TARGET_DIR/volumes/komodo/config.toml"
fi

export PERIPHERY_ROOT_DIRECTORY="${TARGET_DIR}"
export SOPS_AGE_KEY_FILE
source "$TARGET_DIR/stacks/komodo/override.env"
eval "echo \"$(cat "$KOMODO_STACK_DIR/compose.yaml")\"" > "$TARGET_DIR/stacks/komodo/compose.yaml"

# configure periphery
cat <<EOF> /etc/systemd/system/periphery.service
[Unit]
Description=Agent to connect with Komodo Core

[Service]
Environment="HOME=${TARGET_DIR}"
Environment="PERIPHERY_ROOT_DIRECTORY=${TARGET_DIR}"
Environment="SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE}"
ExecStart=${TARGET_DIR}/periphery --config-path ${TARGET_DIR}/periphery.config.toml
Restart=on-failure
TimeoutStartSec=0

[Install]
WantedBy=default.target
EOF

cp "${SCRIPT_DIR}/periphery.config.toml" "${TARGET_DIR}/periphery.config.toml"

version="$(curl -sSL https://api.github.com/repos/moghtech/komodo/releases/latest | jq -r .tag_name)"
curl -sSL -o "${TARGET_DIR}/periphery" "https://github.com/moghtech/komodo/releases/download/${version}/periphery-x86_64"
chmod +x "${TARGET_DIR}/periphery"

version="$(curl -sSL https://api.github.com/repos/getsops/sops/releases/latest | jq -r .tag_name)"
curl -sSL -o "${TARGET_DIR}/sops" "https://github.com/getsops/sops/releases/download/${version}/sops-${version}.linux.amd64"
chmod +x "${TARGET_DIR}/periphery"


systemctl daemon-reload
systemctl restart periphery.service
