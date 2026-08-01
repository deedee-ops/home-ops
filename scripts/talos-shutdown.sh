#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLUSTER="${CLUSTER:-deedee}"
export TALOSCONFIG="${TALOSCONFIG:-${ROOT_DIR}/talos/${CLUSTER}/talosconfig}"
export KUBECONFIG="${KUBECONFIG:-${ROOT_DIR}/talos/${CLUSTER}/kubeconfig}"

DRAIN_TIMEOUT="${DRAIN_TIMEOUT:-600}"
MOUNT_TIMEOUT="${MOUNT_TIMEOUT:-600}"

CEPH_NS="rook-ceph"
NODE_NAMES=()
declare -A NODE_ADDR

DRAIN_SELECTOR='rook_cluster!=rook-ceph'

WORKDIR=""
cleanup() { [[ -n "${WORKDIR}" ]] && rm -rf "${WORKDIR}"; }
trap cleanup EXIT

log() {
  local lvl="$1"
  shift
  if command -v gum >/dev/null 2>&1; then
    gum log -t rfc3339 -s -l "${lvl}" "$@"
  else
    printf '%s [%s] %s\n' "$(date -Is)" "${lvl}" "$*" >&2
  fi
}

die() {
  log error "$@"
  exit 1
}

require() {
  local tool
  for tool in "$@"; do
    command -v "${tool}" >/dev/null 2>&1 || die "missing required tool: ${tool}"
  done
}

ceph_cmd() {
  kubectl -n "${CEPH_NS}" exec deploy/rook-ceph-tools -- ceph "$@"
}

build_ceph_mount_patterns() {
  {
    kubectl get storageclass -o json |
      jq -r '.items[] | select(.provisioner | test("ceph")) | .provisioner'
    kubectl get pv -o json |
      jq -r '.items[] | select(((.spec.csi.driver // "")) | test("ceph")) | .metadata.name'
  } | sort -u >"${WORKDIR}/ceph-patterns"

  local count
  count="$(wc -l <"${WORKDIR}/ceph-patterns")"
  ((count > 0)) || die "found no Ceph CSI drivers or PVs - refusing to guess at mount state"
  log info "Ceph mount match patterns built" count "${count}"
}

discover_nodes() {
  local name addr
  while IFS=$'\t' read -r name addr; do
    [[ -z "${name}" ]] && continue
    NODE_NAMES+=("${name}")
    NODE_ADDR["${name}"]="${addr}"
  done < <(kubectl get nodes -o json |
    jq -r '.items[] | "\(.metadata.name)\t\(.status.addresses[] | select(.type=="InternalIP") | .address)"')

  ((${#NODE_NAMES[@]} > 0)) || die "no nodes found"
}

preflight() {
  require kubectl talosctl jq

  WORKDIR="$(mktemp -d)"

  kubectl cluster-info >/dev/null 2>&1 ||
    die "cannot reach the Kubernetes API - is the cluster already down?"

  discover_nodes
  log info "Target cluster" cluster "${CLUSTER}" nodes "${NODE_NAMES[*]}"

  local health
  health="$(ceph_cmd health detail 2>/dev/null | head -n1 || true)"
  [[ -z "${health}" ]] && die "cannot reach the Ceph toolbox (deploy/rook-ceph-tools in ${CEPH_NS})"

  log info "Ceph health" status "${health}"
  [[ "${health}" == HEALTH_OK* ]] ||
    die "Ceph is not healthy (${health}) - fix it first, or a shutdown from here can wedge on boot"

  build_ceph_mount_patterns
}

cordon_all() {
  log info "Cordoning all nodes"
  local name
  for name in "${NODE_NAMES[@]}"; do
    kubectl cordon "${name}"
  done
}

drain_all() {
  local name rc=0
  local -a pids=() drained=()

  log info "Draining all nodes" selector "${DRAIN_SELECTOR}" timeout "${DRAIN_TIMEOUT}s"

  for name in "${NODE_NAMES[@]}"; do
    kubectl drain "${name}" \
      --ignore-daemonsets \
      --delete-emptydir-data \
      --disable-eviction \
      --pod-selector="${DRAIN_SELECTOR}" \
      --timeout="${DRAIN_TIMEOUT}s" \
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

  return 0
}

ceph_mounts_on_node() {
  local addr="$1"
  talosctl -n "${addr}" mounts 2>/dev/null |
    awk '$NF ~ /^\/var\/lib\/kubelet/' |
    grep -F -f "${WORKDIR}/ceph-patterns" || true
}

wait_for_mounts_drained() {
  local deadline name stuck any expired mount

  deadline=$(($(date +%s) + MOUNT_TIMEOUT))
  log info "Verifying no Ceph mounts remain on any node" timeout "${MOUNT_TIMEOUT}s"

  while :; do
    any=0
    expired=0
    (($(date +%s) >= deadline)) && expired=1

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
      return 0
    }

    ((expired)) &&
      die "refusing to shut down with live Ceph mounts - that is exactly what deadlocks Talos"

    sleep 10
  done
}

shutdown_nodes() {
  local name
  log info "Shutting down nodes sequentially" order "${NODE_NAMES[*]}"

  for name in "${NODE_NAMES[@]}"; do
    log info "Shutting down node" node "${name}" addr "${NODE_ADDR[${name}]}"
    talosctl -n "${NODE_ADDR[${name}]}" shutdown --force --wait=false
    sleep 15
  done

  log info "Shutdown issued to all nodes"
}

main() {
  preflight
  cordon_all
  drain_all
  wait_for_mounts_drained
  shutdown_nodes

  printf '\n  On boot:  kubectl uncordon %s\n\n' "${NODE_NAMES[*]}"
}

main
