#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLUSTER="${CLUSTER:-deedee}"
export TALOSCONFIG="${TALOSCONFIG:-${ROOT_DIR}/talos/${CLUSTER}/talosconfig}"
export KUBECONFIG="${KUBECONFIG:-${ROOT_DIR}/talos/${CLUSTER}/kubeconfig}"

DRAIN_TIMEOUT="${DRAIN_TIMEOUT:-600}"
MOUNT_TIMEOUT="${MOUNT_TIMEOUT:-600}"

UPS_DRAIN_TIMEOUT="${UPS_DRAIN_TIMEOUT:-180}"
UPS_MOUNT_TIMEOUT="${UPS_MOUNT_TIMEOUT:-120}"
UPS_DEADLINE="${UPS_DEADLINE:-420}"
NODE_SHUTDOWN_STAGGER="${NODE_SHUTDOWN_STAGGER:-15}"
UPS_NODES="${UPS_NODES:-}"

TALOSCTL=()
KUBECTL=()

UPS_MODE=0
DRY_RUN=0
START_TS=0

CEPH_NS="rook-ceph"
NODE_NAMES=()
declare -A NODE_ADDR

DRAIN_SELECTOR='rook_cluster!=rook-ceph'

WORKDIR=""
cleanup() {
  local rc=$?
  [[ -n "${WORKDIR}" ]] && rm -rf "${WORKDIR}"
  return "${rc}"
}
trap cleanup EXIT

log() {
  local lvl="$1"
  shift
  if ((UPS_MODE == 0)) && command -v gum >/dev/null 2>&1; then
    gum log -t rfc3339 -s -l "${lvl}" "$@"
  else
    printf '%s [%s] %s\n' "$(date -Is)" "${lvl}" "$*" >&2
  fi
}

emit() {
  ((UPS_MODE)) || return 0
  printf '@@UPS_EVENT %s\n' "$*"
}

die() {
  log error "$@"
  exit 1
}

bail() {
  log error "$@"
  ((UPS_MODE)) && return 1
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage: talos-shutdown.sh [--ups] [--dry-run]

  --ups      unattended mode: soft preflight, tight timeouts, hard deadline,
             machine-readable @@UPS_EVENT lines, force-shutdown fallback
  --dry-run  run preflight and report the plan, change nothing
EOF
  exit 2
}

parse_args() {
  while (($#)); do
    case "$1" in
      --ups) UPS_MODE=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -h | --help) usage ;;
      *)
        printf 'unknown argument: %s\n' "$1" >&2
        usage
        ;;
    esac
    shift
  done
}

budget_left() {
  ((UPS_MODE)) || {
    printf '%s\n' 999999
    return 0
  }
  local left=$((UPS_DEADLINE - ($(date +%s) - START_TS)))
  ((left < 0)) && left=0
  printf '%s\n' "${left}"
}

capped() {
  local want="$1" left
  left="$(budget_left)"
  ((left < want)) && want="${left}"
  ((want < 1)) && want=1
  printf '%s\n' "${want}"
}

require() {
  local tool missing=0
  for tool in "$@"; do
    command -v "${tool}" >/dev/null 2>&1 || {
      log error "missing required tool: ${tool}"
      missing=1
    }
  done
  return "${missing}"
}

ceph_cmd() {
  "${KUBECTL[@]}" -n "${CEPH_NS}" exec deploy/rook-ceph-tools -- ceph "$@"
}

build_ceph_mount_patterns() {
  {
    "${KUBECTL[@]}" get storageclass -o json |
      jq -r '.items[] | select(.provisioner | test("ceph")) | .provisioner'
    "${KUBECTL[@]}" get pv -o json |
      jq -r '.items[] | select(((.spec.csi.driver // "")) | test("ceph")) | .metadata.name'
  } | sort -u >"${WORKDIR}/ceph-patterns"

  local count
  count="$(wc -l <"${WORKDIR}/ceph-patterns")"
  ((count > 0)) || return 1
  log info "Ceph mount match patterns built" count "${count}"
}

nodes_from_env() {
  local -a items
  local item name addr
  [[ -n "${UPS_NODES}" ]] || return 1
  IFS=',' read -ra items <<<"${UPS_NODES}"
  for item in "${items[@]}"; do
    [[ "${item}" == *=* ]] || continue
    name="${item%%=*}"
    addr="${item#*=}"
    NODE_NAMES+=("${name}")
    NODE_ADDR["${name}"]="${addr}"
  done
  ((${#NODE_NAMES[@]} > 0))
}

discover_nodes() {
  local name addr
  while IFS=$'\t' read -r name addr; do
    [[ -z "${name}" ]] && continue
    NODE_NAMES+=("${name}")
    NODE_ADDR["${name}"]="${addr}"
  done < <("${KUBECTL[@]}" get nodes -o json 2>/dev/null |
    jq -r '.items[] | "\(.metadata.name)\t\(.status.addresses[] | select(.type=="InternalIP") | .address)"' 2>/dev/null)

  ((${#NODE_NAMES[@]} > 0))
}

preflight() {
  WORKDIR="$(mktemp -d)"

  TALOSCTL=(talosctl --talosconfig "${TALOSCONFIG}")
  KUBECTL=(kubectl --kubeconfig "${KUBECONFIG}")

  local f
  for f in "${TALOSCONFIG}" "${KUBECONFIG}"; do
    [[ -r "${f}" ]] && continue
    log error "credential not readable: ${f}"
    emit talos_preflight_degraded reason=credentials_unreadable
    ((UPS_MODE)) && return 2
    exit 1
  done

  if ((UPS_MODE)); then
    require talosctl || {
      log error "talosctl is unavailable - nothing can be shut down from here"
      return 2
    }
    if ! require kubectl jq; then
      nodes_from_env || return 2
      emit talos_preflight_degraded reason=missing_tools
      return 1
    fi
  else
    require kubectl talosctl jq || die "missing required tooling"
  fi

  if ! discover_nodes; then
    if nodes_from_env; then
      log warn "Kubernetes API unreachable - node list taken from UPS_NODES"
      emit talos_preflight_degraded reason=api_unreachable
      return 1
    fi
    bail "no nodes found and no UPS_NODES fallback" || return 2
  fi

  log info "Target cluster" cluster "${CLUSTER}" nodes "${NODE_NAMES[*]}"

  if ! "${KUBECTL[@]}" cluster-info >/dev/null 2>&1; then
    bail "cannot reach the Kubernetes API - is the cluster already down?" || {
      emit talos_preflight_degraded reason=api_unreachable
      return 1
    }
  fi

  local health
  health="$(ceph_cmd health detail 2>/dev/null | head -n1 || true)"
  if [[ -z "${health}" ]]; then
    bail "cannot reach the Ceph toolbox (deploy/rook-ceph-tools in ${CEPH_NS})" || {
      emit talos_preflight_degraded reason=toolbox_unreachable
      return 1
    }
  fi

  log info "Ceph health" status "${health}"
  if [[ "${health}" != HEALTH_OK* ]]; then
    if ((UPS_MODE)); then
      log warn "Ceph is not healthy - proceeding anyway (ups mode)" status "${health}"
      emit talos_ceph_unhealthy status="${health// /_}"
    else
      die "Ceph is not healthy (${health}) - fix it first, or a shutdown from here can wedge on boot"
    fi
  fi

  if ! build_ceph_mount_patterns; then
    bail "found no Ceph CSI drivers or PVs - refusing to guess at mount state" || {
      emit talos_preflight_degraded reason=no_ceph_patterns
      return 1
    }
  fi

  emit talos_preflight_ok nodes="$(
    IFS=,
    printf '%s' "${NODE_NAMES[*]}"
  )"
  return 0
}

cordon_all() {
  log info "Cordoning all nodes"
  local name
  for name in "${NODE_NAMES[@]}"; do
    "${KUBECTL[@]}" cordon "${name}" || return 1
  done
  emit talos_cordoned
}

drain_all() {
  local name timeout rc=0
  local -a pids=() drained=()

  timeout="${DRAIN_TIMEOUT}"
  ((UPS_MODE)) && timeout="$(capped "${UPS_DRAIN_TIMEOUT}")"

  log info "Draining all nodes" selector "${DRAIN_SELECTOR}" timeout "${timeout}s"

  for name in "${NODE_NAMES[@]}"; do
    "${KUBECTL[@]}" drain "${name}" \
      --ignore-daemonsets \
      --delete-emptydir-data \
      --disable-eviction \
      --pod-selector="${DRAIN_SELECTOR}" \
      --timeout="${timeout}s" \
      >"${WORKDIR}/drain-${name}.log" 2>&1 &

    pids+=("$!")
    drained+=("${name}")
  done

  local i
  for i in "${!pids[@]}"; do
    if wait "${pids[$i]}"; then
      log info "Drained" node "${drained[$i]}"
    else
      rc=1
      log error "Drain failed" node "${drained[$i]}"
      sed 's/^/    /' "${WORKDIR}/drain-${drained[$i]}.log" >&2 || true
    fi
  done

  ((rc)) && log warn "At least one node failed to drain - the mount check decides"

  emit talos_drained failed="${rc}"
  return 0
}

ceph_mounts_on_node() {
  local addr="$1" out rc=0
  out="$("${TALOSCTL[@]}" -n "${addr}" mounts 2>&1)" || rc=$?
  if ((rc != 0)); then
    log error "cannot read mounts - treating as NOT clear" addr "${addr}" output "${out}"
    printf 'UNREADABLE %s\n' "${addr}"
    return 0
  fi
  printf '%s\n' "${out}" |
    awk '$NF ~ /^\/var\/lib\/kubelet/' |
    grep -F -f "${WORKDIR}/ceph-patterns" || true
}

wait_for_mounts_drained() {
  local deadline name stuck any expired mount timeout

  timeout="${MOUNT_TIMEOUT}"
  ((UPS_MODE)) && timeout="$(capped "${UPS_MOUNT_TIMEOUT}")"

  deadline=$(($(date +%s) + timeout))
  log info "Verifying no Ceph mounts remain on any node" timeout "${timeout}s"

  while :; do
    any=0
    expired=0
    (($(date +%s) >= deadline)) && expired=1
    if ((UPS_MODE)) && (($(budget_left) == 0)); then
      expired=1
    fi

    for name in "${NODE_NAMES[@]}"; do
      stuck="$(ceph_mounts_on_node "${NODE_ADDR[${name}]}")"
      [[ -z "${stuck}" ]] && continue
      any=1
      if ((expired)); then
        log error "Ceph mounts still present" node "${name}"
        while IFS= read -r mount; do
          printf '    %s\n' "${mount}" >&2
        done <<<"${stuck}"
      fi
    done

    ((any == 0)) && {
      log info "All nodes are free of Ceph mounts"
      emit talos_mounts_clear
      return 0
    }

    if ((expired)); then
      if ((UPS_MODE)); then
        log error "Ceph mounts still live at the deadline - shutting down anyway (ups mode)"
        emit talos_mounts_timeout
        return 1
      fi
      die "refusing to shut down with live Ceph mounts - that is exactly what deadlocks Talos"
    fi

    sleep 10
  done
}

shutdown_one() {
  local name="$1" out rc=0
  out="$("${TALOSCTL[@]}" -n "${NODE_ADDR[${name}]}" shutdown --force --wait=false 2>&1)" || rc=$?
  if ((rc == 0)); then
    emit talos_node_shutdown node="${name}" rc=0
  else
    log error "Shutdown call failed" node "${name}" rc "${rc}" output "${out}"
    emit talos_node_shutdown node="${name}" rc="${rc}" error="${out//[[:space:]]/_}"
  fi
  return "${rc}"
}

shutdown_nodes() {
  local name failed=0
  log info "Shutting down nodes sequentially" order "${NODE_NAMES[*]}"
  emit talos_point_of_no_return mode=graceful

  for name in "${NODE_NAMES[@]}"; do
    log info "Shutting down node" node "${name}" addr "${NODE_ADDR[${name}]}"
    shutdown_one "${name}" || failed=$((failed + 1))
    sleep "${NODE_SHUTDOWN_STAGGER}"
  done

  log info "Shutdown issued to all nodes" failed "${failed}"
  emit talos_shutdown_issued failed="${failed}" total="${#NODE_NAMES[@]}"
  ((failed == ${#NODE_NAMES[@]})) && emit talos_shutdown_all_failed
  return 0
}

force_shutdown_all() {
  local name failed=0
  log warn "Forcing shutdown on all nodes without the graceful path"
  emit talos_point_of_no_return mode=forced
  emit talos_forced

  for name in "${NODE_NAMES[@]}"; do
    log warn "Force shutting down node" node "${name}" addr "${NODE_ADDR[${name}]}"
    shutdown_one "${name}" || failed=$((failed + 1))
  done

  emit talos_shutdown_issued failed="${failed}" total="${#NODE_NAMES[@]}"
  ((failed == ${#NODE_NAMES[@]})) && emit talos_shutdown_all_failed
  return 0
}

report_plan() {
  printf '\n  DRY RUN - nothing was changed.\n\n'
  printf '  cluster:   %s\n' "${CLUSTER}"
  printf '  nodes:     %s\n' "${NODE_NAMES[*]}"
  printf '  selector:  %s\n' "${DRAIN_SELECTOR}"
  if ((UPS_MODE)); then
    printf '  budget:    %ss total, drain %ss, mounts %ss\n' \
      "${UPS_DEADLINE}" "${UPS_DRAIN_TIMEOUT}" "${UPS_MOUNT_TIMEOUT}"
  else
    printf '  timeouts:  drain %ss, mounts %ss\n' "${DRAIN_TIMEOUT}" "${MOUNT_TIMEOUT}"
  fi
  printf '\n  Would: cordon -> drain -> wait for mounts -> shutdown %s\n\n' "${NODE_NAMES[*]}"
}

main() {
  parse_args "$@"
  START_TS="$(date +%s)"

  local pf=0
  preflight || pf=$?

  if ((pf == 2)); then
    emit talos_aborted reason=preflight
    exit 1
  fi

  if ((DRY_RUN)); then
    emit talos_dry_run degraded="${pf}"
    report_plan
    exit 0
  fi

  if ((pf == 1)); then
    force_shutdown_all
    exit 0
  fi

  if ! cordon_all; then
    log error "Cordon failed"
    if ((UPS_MODE)); then
      force_shutdown_all
      exit 0
    fi
    exit 1
  fi

  drain_all

  if ! wait_for_mounts_drained; then
    force_shutdown_all
    exit 0
  fi

  shutdown_nodes

  printf '\n  On boot:  kubectl uncordon %s\n\n' "${NODE_NAMES[*]}"
}

main "$@"
