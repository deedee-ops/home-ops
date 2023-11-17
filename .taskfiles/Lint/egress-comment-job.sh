#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# search for enabled exgresses without reason
result="$(find "${SCRIPT_DIR}/../../" -name '*.yaml' -exec sh -c "grep -H -B1 'egress/enabled:' \$1 | grep -v '\s*#' | grep -v 'egress/enabled:' | awk '{ print \$1 }' | sed 's@-*\$@@g'" shell {} \;)"
if [ -n "${result}" ]; then
  echo "Found enabled egresses without comment:"
  echo "${result}" | awk '{ print "- " $0 }' | sed "s@${SCRIPT_DIR}/../../@./@g"
  exit 1
fi

echo "All good!"
exit 0
