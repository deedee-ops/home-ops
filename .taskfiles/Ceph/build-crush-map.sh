#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
POD="$(kubectl get pods -n rook-ceph -l=app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}')"

hcl2json "$1" > /tmp/ceph-config.json

kubectl cp -n rook-ceph /tmp/ceph-config.json "${POD}:/tmp/ceph-config.json"
kubectl cp -n rook-ceph "${SCRIPT_DIR}/crush-helper.sh" "${POD}:/tmp/crush-helper.sh"

kubectl -n rook-ceph exec -it "${POD}" -- sh -c '/tmp/crush-helper.sh /tmp/ceph-config.json | bash'
