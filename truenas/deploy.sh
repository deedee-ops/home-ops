#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CONTEXT="$1"
TARGET_DIR="$2"

HOSTS_DIR="$(realpath "$SCRIPT_DIR/../docker/hosts")"
SEARCH_DIR="$(realpath "$SCRIPT_DIR/../docker/stacks")"
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

if ! command -v sops &> /dev/null; then
  alias sops="docker run --rm -it ghcr.io/getsops/sops:v3.11.0-alpine"
fi

if ! test -f "$SOPS_AGE_KEY_FILE"; then
    echo "Error: missing age key file at $SOPS_AGE_KEY_FILE"
    exit 1
fi

# prepare compose files and envs
find "$SEARCH_DIR" -type f -name "compose.yaml" | sort | while read -r compose_file; do
    # Get the directory containing the docker-compose.yml file
    stack_dir=$(dirname "$compose_file")
    stack_name=$(basename "$stack_dir")

    echo "Processing directory: $stack_dir"

    mkdir -p "$TARGET_DIR/stacks/$stack_name"
    cp "$stack_dir/"* "$TARGET_DIR/stacks/$stack_name/"

    if test -f "$HOSTS_DIR/$CONTEXT/$stack_name.sops.env"; then
      sops -d "$HOSTS_DIR/$CONTEXT/$stack_name.sops.env" > "$TARGET_DIR/stacks/$stack_name/override.env"
    fi
done

# configure periphery
cat <<EOF> /etc/systemd/system/periphery.service
[Unit]
Description=Agent to connect with Komodo Core

[Service]
Environment="HOME=${TARGET_DIR}"
Environment="PERIPHERY_ROOT_DIRECTORY=${TARGET_DIR}"
EnvironmentFile="${TARGET_DIR}/stacks/komodo/override.env"
ExecStart=/bin/sh -lc "${TARGET_DIR}/periphery --config-path ${TARGET_DIR}/periphery.config.toml"
Restart=on-failure
TimeoutStartSec=0

[Install]
WantedBy=default.target
EOF

cp "${SCRIPT_DIR}/periphery.config.toml" "${TARGET_DIR}/periphery.config.toml"

curl -sSL -o "${TARGET_DIR}/periphery" "https://github.com/moghtech/komodo/releases/download/v1.19.5/periphery-x86_64"
chmod +x "${TARGET_DIR}/periphery"

systemctl daemon-reload
systemctl restart periphery.service
