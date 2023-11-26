#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
POD="$(kubectl get pods -n rook-ceph -l=app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}')"

hcl2json "$1" > /tmp/ceph-config.json

kubectl cp -n rook-ceph /tmp/ceph-config.json "${POD}:/tmp/ceph-config.json"
kubectl cp -n rook-ceph "${SCRIPT_DIR}/crush-helper.sh" "${POD}:/tmp/crush-helper.sh"

ROOK_PODS="$(kubectl -n rook-ceph get pods -l app=rook-discover | grep rook-discover | awk '{print $1}')"
DISKS="$(jq -r '.cluster.ceph.storage_nodes[].devices[].name' < /tmp/ceph-config.json)"

while read -r pod; do while read -r disk; do echo "kubectl -n rook-ceph exec -i ${pod} -- bash -c '[ -e ${disk} ] && echo \"${disk} \$(readlink -f ${disk})\"' 2>&1"; done <<< "${DISKS}"; done <<< "${ROOK_PODS}" > /tmp/build-disk-map
bash /tmp/build-disk-map | grep -v terminated > /tmp/disk-map
kubectl cp -n rook-ceph /tmp/disk-map "${POD}:/tmp/disk-map"

kubectl -n rook-ceph exec -it "${POD}" -- sh -c '/tmp/crush-helper.sh /tmp/ceph-config.json | bash'
