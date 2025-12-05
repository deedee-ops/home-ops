#!/usr/bin/env bash
# shellcheck disable=SC2154
set -euo pipefail

echo "INFO : Refreshing jellyfin ..."
curl -X POST "http://jellyfin.media.svc.cluster.local:8096/library/refresh?api_key=${JELLYFIN_API_KEY}"
