#!/bin/bash
set -e

CONTEXT="${1:-meemee}"
TARGET_DIR="${2:-/mnt/apps/docker}"
INITPARAM="$3"
SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE:-"${TARGET_DIR}/age-keys.txt"}

mkdir -p "$TARGET_DIR/stacks" "$TARGET_DIR/volumes/komodo"

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

# set TERMINFO
mount -o remount,rw /usr
echo -n 'GgEeAB0ADwBpAbIFeHRlcm0tZ2hvc3R0eXxnaG9zdHR5fEdob3N0dHkAAAEAAAEAAAABAQAAAAEBAAAAAAAAAAEAAAEAAQEAUAAIABgA//////////////////////////8AAf9/AAAEAAYACAAZAB4AJgAqAC4A//85AEoATABQAFcA//9ZAGYA//9qAG4AeAB8AIAA//+GAIoAjwCUAP//nQCiAKcA//+sALEAtgC7AMQAyADPAP//2ADdAOMA6QD///sA///////////9AAEB//8FAf///////wcB//8MAf//////////EAEUARoBHgEiASYBLAEyATgBPgFEAUgB//9NAf//UQFWAVsBXwFmAf//bQFxAXkB////////////////////////////////////////gQGKAZMBnAGlAa4BtwHAAckB0gH////////////////bAe8B////////9gH5AQQCBwIJAgwCXgL//2ECYwL//////////////////////////2gC//+pAv////+tArMC/////////////////////////////7kCvQL//////////////////////////////////////////////////////////////////8EC/////8gC///////////PAtYC3QL/////5AL//+sC////////8gL/////////////+QL/AgUDDAMTAxoDIQMpAzEDOQNBA0kDUQNZA2EDaANvA3YDfQOFA40DlQOdA6UDrQO1A70DxAPLA9ID2QPhA+kD8QP5AwEECQQRBBkEIAQnBC4ENQQ9BEUETQRVBF0EZQRtBHUEfASDBIoE/////////////////////////////////////////////////////////////48EmgSfBLIEtgS/BMYE/////////////////////////////yQF////////////////////////KQX///////////////////////////////////////////////////////////////////////////////////////8vBf///////zMFcgUbW1oABwANABtbJWklcDElZDslcDIlZHIAG1szZwAbW0gbWzJKABtbSwAbW0oAG1slaSVwMSVkRwAbWyVpJXAxJWQ7JXAyJWRIAAoA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OyVwMiVzBwAbWzIwMX4AG1syMDB+ABtbPmMAG1syIHEAG1s1ODoyOjolcDElezY1NTM2fSUvJWQ6JXAxJXsyNTZ9JS8lezI1NX0lJiVkOiVwMSV7MjU1fSUmJWQlO20AG1s0OiVwMSVkbQAbWyVwMSVkIHEAG1s/MjAyNiU/JXAxJXsxfSUtJXRsJWVoJTsAG1s/MTAwNjsxMDAwJT8lcDElezF9JT0ldGglZWwlOwAbWz4wcQAbWz8xMDA0bAAbWz8xMDA0aAAbWzM7M34AG1szOzR+ABtbMzs1fgAbWzM7Nn4AG1szOzd+ABtbMTsyQgAbWzE7M0IAG1sxOzRCABtbMTs1QgAbWzE7NkIAG1sxOzdCABtbMTszRgAbWzE7NEYAG1sxOzVGABtbMTs2RgAbWzE7N0YAG1sxOzNIABtbMTs0SAAbWzE7NUgAG1sxOzZIABtbMTs3SAAbWzI7M34AG1syOzR+ABtbMjs1fgAbWzI7Nn4AG1syOzd+ABtbMTszRAAbWzE7NEQAG1sxOzVEABtbMTs2RAAbWzE7N0QAG1s2OzN+ABtbNjs0fgAbWzY7NX4AG1s2OzZ+ABtbNjs3fgAbWzU7M34AG1s1OzR+ABtbNTs1fgAbWzU7Nn4AG1s1Ozd+ABtbMTszQwAbWzE7NEMAG1sxOzVDABtbMTs2QwAbWzE7N0MAG1sxOzJBABtbMTszQQAbWzE7NEEAG1sxOzVBABtbMTs2QQAbWzE7N0EAG1tJABtbTwAbWzI5bQAbXFtbMC05XSs7WzAtOV0rO1swLTldK2MAG1s0ODoyOiVwMSVkOiVwMiVkOiVwMyVkbQAbWzM4OjI6JXAxJWQ6JXAyJWQ6JXAzJWRtABtbOW0AG1s8JWklcDMlZDslcDElZDslcDIlZDslPyVwNCV0TSVlbSU7ABtQPlx8WyAtfl0rYRtcAEFYAFN1AFRjAFhUAGZ1bGxrYmQAQkQAQkUAQ2xtZwBDbWcARHNtZwBFMwBFbm1nAE1zAFBFAFBTAFJWAFNlAFNldHVsYwBTbXVseABTcwBTeW5jAFhNAFhSAGZkAGZlAGtEQzMAa0RDNABrREM1AGtEQzYAa0RDNwBrRE4Aa0ROMwBrRE40AGtETjUAa0RONgBrRE43AGtFTkQzAGtFTkQ0AGtFTkQ1AGtFTkQ2AGtFTkQ3AGtIT00zAGtIT000AGtIT001AGtIT002AGtIT003AGtJQzMAa0lDNABrSUM1AGtJQzYAa0lDNwBrTEZUMwBrTEZUNABrTEZUNQBrTEZUNgBrTEZUNwBrTlhUMwBrTlhUNABrTlhUNQBrTlhUNgBrTlhUNwBrUFJWMwBrUFJWNABrUFJWNQBrUFJWNgBrUFJWNwBrUklUMwBrUklUNABrUklUNQBrUklUNgBrUklUNwBrVVAAa1VQMwBrVVA0AGtVUDUAa1VQNgBrVVA3AGt4SU4Aa3hPVVQAcm14eABydgBzZXRyZ2JiAHNldHJnYmYAc214eAB4bQB4cgA=' | base64 -d > /usr/share/terminfo/x/xterm-ghostty
ln -s /usr/share/terminfo/x/xterm-ghostty /usr/share/terminfo/g/ghostty
mount -o remount,ro /usr

# deploy containers

version="$(curl -sSL https://api.github.com/repos/getsops/sops/releases/latest | jq -r .tag_name)"
digest="$(curl -sSL https://api.github.com/repos/getsops/sops/releases/latest | jq -r '.assets[] | select(.name == "sops-'"${version}"'.linux.amd64") | .digest')"
if [ ! -f "${TARGET_DIR}/sops" ] || [[ "sha256:$(sha256sum "${TARGET_DIR}/sops" | awk '{print $1}')" != "${digest}" ]]; then
  url="$(curl -sSL https://api.github.com/repos/getsops/sops/releases/latest | jq -r '.assets[] | select(.name == "sops-'"${version}"'.linux.amd64") | .browser_download_url')"
  curl -sSL -o "${TARGET_DIR}/sops" "${url}"
  chmod +x "${TARGET_DIR}/sops"
fi

if [[ "${INITPARAM}" == "--init" ]]; then
  rm -rf "$TARGET_DIR/stacks/komodo" || true
  git clone https://github.com/deedee-ops/home-ops "$TARGET_DIR/stacks/komodo"

  KOMODO_STACK_DIR="$TARGET_DIR/stacks/komodo/docker/stacks/komodo"
  HOSTS_DIR="$TARGET_DIR/stacks/komodo/docker/hosts"

  if test -f "$HOSTS_DIR/$CONTEXT/bootstrap/komodo.sops.env"; then
    "${TARGET_DIR}/sops" -d "$HOSTS_DIR/$CONTEXT/bootstrap/komodo.sops.env" > "$KOMODO_STACK_DIR/override.env"
  fi

  if test -f "$HOSTS_DIR/$CONTEXT/bootstrap/config.sops.toml"; then
    "${TARGET_DIR}/sops" -d "$HOSTS_DIR/$CONTEXT/bootstrap/config.sops.toml" > "$TARGET_DIR/volumes/komodo/config.toml"
  fi

  export PERIPHERY_ROOT_DIRECTORY="${TARGET_DIR}"

  # shellcheck source=/dev/null
  source "${KOMODO_STACK_DIR}/override.env"

  eval "echo \"$(cat "$KOMODO_STACK_DIR/compose.yaml" | sed 's@`@#-#@g')\"" | sed 's@#-#@`@g' > /tmp/kcompose.yaml
  mv /tmp/kcompose.yaml "$KOMODO_STACK_DIR/compose.yaml"
fi

cp "${TARGET_DIR}/stacks/komodo/scripts/nas/periphery.config.toml" "${TARGET_DIR}/periphery.config.toml"

digest="$(curl -sSL https://api.github.com/repos/moghtech/komodo/releases/latest | jq -r '.assets[] | select(.name == "periphery-x86_64") | .digest')"
if [ ! -f "${TARGET_DIR}/periphery" ] || [[ "sha256:$(sha256sum "${TARGET_DIR}/periphery" | awk '{print $1}')" != "${digest}" ]]; then
  url="$(curl -sSL https://api.github.com/repos/moghtech/komodo/releases/latest | jq -r '.assets[] | select(.name == "periphery-x86_64") | .browser_download_url')"
  curl -sSL -o "${TARGET_DIR}/periphery" "${url}"
  chmod +x "${TARGET_DIR}/periphery"
fi

ln -s "${TARGET_DIR}" /etc/komodo

# configure periphery
cat <<EOF | tee /etc/systemd/system/periphery.service
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

systemctl daemon-reload
systemctl enable --now periphery.service

if [[ "${INITPARAM}" == "--init" ]]; then
  docker network create internal || true

  cd "${KOMODO_STACK_DIR}" && docker compose -p komodo -f compose.yaml up -d
fi

# configure exports patcher
cat <<EOF | tee /etc/systemd/system/nfs-exports-fixer.service
[Unit]
Description=Fix NFS exports with custom fsid
After=nfs-server.service
Wants=nfs-server.service

[Service]
Type=oneshot
ExecStart=/mnt/apps/docker/volumes/truenas/nfs-exports-fixer.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | tee /etc/systemd/system/nfs-exports-watcher.path
[Unit]
Description=Monitor NFS exports file for changes
After=nfs-server.service

[Path]
PathModified=/etc/exports
Unit=nfs-exports-fixer.service

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nfs-exports-fixer.service
systemctl enable --now nfs-exports-watcher.path


# vim:ft=bash
