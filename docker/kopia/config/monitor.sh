#!/usr/bin/env bash
#
# Monitoring for the backblaze b2 repository. Three independent healthchecks.io
# checks, all derived from one base ping URL (host + ping key, no slug):
#
#   <base>/kopiur-backups        daily     - every source has a recent snapshot
#   <base>/kopiur-verify-quick   every 3d  - blob-level integrity
#   <base>/kopiur-verify-deep    monthly   - full content download + hash check
#
# On failure the same URL gets /fail appended, with the diagnostic as the body so
# the alert names the problem.
#
# The backup check verifies *outcomes* rather than hooking snapshot events.
# kopia can post a webhook itself, but notification profiles gate on a minimum
# severity only - a profile aimed at the success URL also fires on warning and
# error, which would turn a failed backup green. It also emits one report per
# source (MaxParallelSnapshots is 1), so any single success would mask another
# source rotting. Checking results instead also catches a deleted policy, a
# dropped source, or a server that never came up.
set -euo pipefail

: "${HEALTHCHECKS_URL:?HEALTHCHECKS_URL must be set (e.g. https://hc-ping.com/<ping-key>, no slug)}"

BACKUPS_AT="${BACKUPS_AT:-20:00}"
BACKUPS_MAX_AGE_HOURS="${BACKUPS_MAX_AGE_HOURS:-12}"

QUICK_AT="${QUICK_AT:-05:00}"
QUICK_EVERY_DAYS="${QUICK_EVERY_DAYS:-3}"

DEEP_AT="${DEEP_AT:-07:00}"
DEEP_DAY_OF_MONTH="${DEEP_DAY_OF_MONTH:-1}"
DEEP_FILES_PERCENT="${DEEP_FILES_PERCENT:-100}"

SLUG_BACKUPS="kopiur-backups"
SLUG_QUICK="kopiur-verify-quick"
SLUG_DEEP="kopiur-verify-deep"

# Survives restarts so a crash loop cannot re-trigger a multi-hour deep verify.
STATE_DIR="${STATE_DIR:-/config/monitor-state}"

# Identity the b2 server snapshots as; see repository-b2.config.
OWNER_USER="root"
OWNER_HOST="nas"

# Must match the sources registered on kopia-b2-host.
SOURCES=(
  /mnt/fast/backups
  /mnt/fast/docker
  /mnt/tank/documents
  /mnt/tank/photos
  /mnt/tank/private
)

# Always pass --sources explicitly. With no source arguments `snapshot verify`
# walks *every* manifest in the repository, which here means verifying the whole
# cluster's backups as well - not our job, and enormously expensive.
SOURCE_ARGS=()
for s in "${SOURCES[@]}"; do
  SOURCE_ARGS+=(--sources "${OWNER_USER}@${OWNER_HOST}:${s}")
done

log() {
  printf '%s %s\n' "$(date -Is)" "$*"
}

state_get() {
  cat "${STATE_DIR}/$1" 2>/dev/null || true
}

state_set() {
  mkdir -p "${STATE_DIR}"
  date +%F >"${STATE_DIR}/$1"
}

# ping <slug> <suffix> <body>   suffix is "" for success, "/fail", or "/start"
ping() {
  local slug="$1" suffix="$2" body="$3"
  local url="${HEALTHCHECKS_URL%/}/${slug}${suffix}"

  if ! curl -fsS -m 30 --retry 3 --retry-delay 5 \
       --data-raw "${body}" "${url}" >/dev/null; then
    log "WARNING: healthchecks ping ${slug}${suffix} failed"
  fi
}

# healthchecks stores a bounded body; keep the useful tail.
trim() {
  tail -n 40 | tail -c 4000
}

# Emits one line per unhealthy source, nothing when all are fresh. Checkpoints
# (`incomplete`) do not count, and kopiur's snapshots are filtered by user@host.
# shellcheck disable=SC2016  # $user/$host/$now/$want are jq variables, not shell
readonly FILTER='
( [ .[]
    | select(.source.userName == $user and .source.host == $host)
    | select(has("incomplete") | not)
    | { path: .source.path,
        end:  (.endTime | sub("\\.[0-9]+"; "") | fromdateiso8601) }
  ]
  | group_by(.path)
  | map({ key: .[0].path, value: (map(.end) | max) })
  | from_entries
) as $newest
| $want[]
| . as $p
| ($newest[$p] // null) as $t
| if $t == null then
    "MISSING  \($p)"
  elif ($now - $t) > $maxage then
    "STALE    \($p)  last completed \((($now - $t) / 3600) | floor)h ago"
  else
    empty
  end
'

check_backups() {
  local snapshots want report

  if ! snapshots=$(kopia snapshot list --all --json 2>&1); then
    printf 'UNREACHABLE  could not list snapshots:\n%s\n' "${snapshots}"
    return 1
  fi

  want=$(printf '%s\n' "${SOURCES[@]}" | jq -R . | jq -s .)

  report=$(printf '%s' "${snapshots}" | jq -r \
    --arg user "${OWNER_USER}" \
    --arg host "${OWNER_HOST}" \
    --argjson maxage "$((BACKUPS_MAX_AGE_HOURS * 3600))" \
    --argjson now "$(date +%s)" \
    --argjson want "${want}" \
    "${FILTER}")

  if [[ -n "${report}" ]]; then
    printf '%s\n' "${report}"
    return 1
  fi

  printf 'all %d sources have a completed snapshot within %sh\n' \
    "${#SOURCES[@]}" "${BACKUPS_MAX_AGE_HOURS}"
}

run_backups() {
  local body
  if body=$(check_backups); then
    log "backups OK: ${body}"
    ping "${SLUG_BACKUPS}" "" "${body}"
  else
    log "backups FAILED:"
    printf '%s\n' "${body}"
    ping "${SLUG_BACKUPS}" "/fail" "${body}"
  fi
  return 0
}

# run_verify <tier> <slug> [extra kopia flags...]
run_verify() {
  local tier="$1" slug="$2"
  shift 2
  local out started elapsed tail body

  log "${tier} verification starting"
  ping "${slug}" "/start" ""
  started=$(date +%s)

  local ok=0
  out=$(kopia snapshot verify "${SOURCE_ARGS[@]}" "$@" 2>&1) || ok=$?
  elapsed=$(($(date +%s) - started))
  tail=$(printf '%s' "${out}" | trim)

  if ((ok == 0)); then
    log "${tier} verification OK in ${elapsed}s"
    body="verified ${#SOURCES[@]} sources in ${elapsed}s"
    ping "${slug}" "" "$(printf '%s\n%s\n' "${body}" "${tail}")"
  else
    log "${tier} verification FAILED after ${elapsed}s"
    printf '%s\n' "${tail}"
    body="${tier} verification failed after ${elapsed}s (exit ${ok})"
    ping "${slug}" "/fail" "$(printf '%s\n%s\n' "${body}" "${tail}")"
  fi
  return 0
}

# Due if the wall clock has passed HH:MM today and the job has not run today.
# Missing a slot (container down) means it runs on the next poll, not never.
due() {
  local name="$1" at="$2"

  [[ "$(date +%H:%M)" < "${at}" ]] && return 1
  [[ "$(state_get "${name}")" == "$(date +%F)" ]] && return 1
  return 0
}

log "monitoring ${#SOURCES[@]} sources on ${OWNER_USER}@${OWNER_HOST}"
log "  backups   daily at ${BACKUPS_AT} (max age ${BACKUPS_MAX_AGE_HOURS}h)  -> ${SLUG_BACKUPS}"
log "  quick     every ${QUICK_EVERY_DAYS}d at ${QUICK_AT}                  -> ${SLUG_QUICK}"
log "  deep      day ${DEEP_DAY_OF_MONTH} at ${DEEP_AT} (${DEEP_FILES_PERCENT}% of files) -> ${SLUG_DEEP}"

while true; do
  day=$(date +%d)

  if due backups "${BACKUPS_AT}"; then
    run_backups
    state_set backups
  fi

  # day-of-month stepping, matching cron's */N semantics (1, 1+N, 1+2N, ...)
  if (((10#${day} - 1) % QUICK_EVERY_DAYS == 0)) && due quick "${QUICK_AT}"; then
    run_verify quick "${SLUG_QUICK}"
    state_set quick
  fi

  if ((10#${day} == DEEP_DAY_OF_MONTH)) && due deep "${DEEP_AT}"; then
    run_verify deep "${SLUG_DEEP}" --verify-files-percent "${DEEP_FILES_PERCENT}"
    state_set deep
  fi

  sleep 30
done
