#!/usr/bin/env bash
# shellcheck disable=SC2154
set -euo pipefail

echo "INFO : Refreshing jellyfin ..."
curl -X POST -H "Authorization: MediaBrowser Token=\"${JELLYFIN_API_KEY}\"" http://jellyfin:8096/Library/Refresh
