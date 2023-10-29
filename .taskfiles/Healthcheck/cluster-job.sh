#!/usr/bin/env bash

# Check for dockerhub images

# Some containers are in DOCKER OSS program and are not subject to ratelimiting
# - rook/ceph : https://github.com/rook/rook/issues/7881#issuecomment-1400878584
DOCKER_OSS="rook/ceph"

result="$(kubectl get pods -A -o yaml | yq 'del(.items[].status)' | grep 'image:' | sed -E 's@\s-@@g' | awk '{ print $2 }' | sort | uniq | grep -v '^registry\.k8s\.io/' | grep -E '(^[^/]+/[^/]+$)|(^docker\.io)' | grep -vE "^(${DOCKER_OSS}):" | cat)"

if [ -n "${result}" ]; then
  echo "Found ratelimited dockerhub images in cluster:"
  echo "${result}" | awk '{ print "- " $0 }'
  exit 1
fi

echo "All good!"
exit 0
