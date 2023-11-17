#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# search for CRDs without corresponding cluster schemas
bash -c "${SCRIPT_DIR}/crd-extractor.sh > /dev/null 2>&1"
result="$(diff -qr /tmp/crdSchemas "${SCRIPT_DIR}/../../schemas")"
if [ -n "${result}" ]; then
  echo "Found missing cluster schemas:"
  echo "${result}" | awk '{ print "- " $0 }'
  exit 1
fi

echo "All good!"
exit 0
