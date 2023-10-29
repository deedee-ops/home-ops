#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

bash -c "${SCRIPT_DIR}/crd-extractor.sh > /dev/null 2>&1"

result="$(diff -qr /tmp/crdSchemas "${SCRIPT_DIR}/../../schemas")"
if [ -n "${result}" ]; then
  echo "Found missing cluster schemas:"
  echo "${result}" | awk '{ print "- " $0 }'
  exit 1
fi

finder="find . \\( -name \\*.y\\*ml -not -name \\*.tmpl.y\\*ml -not -name values.y\\*ml -not -path ./$(yq '.ignore|join(" -not -path ./")' < "${SCRIPT_DIR}/../../.yamllint" | sed 's@*@\\\*@g') \\) -exec grep -Hoc 'yaml-language-serve' {} \\;"
result="$(sh -c "${finder}" | grep ':0$' | awk -F: '{ print $1 }')"

if [ -n "${result}" ]; then
  echo "Found YAML files without JSON schema manifest links:"
  echo "${result}" | awk '{ print "- " $0 }' | sed "s@${SCRIPT_DIR}/../../@./@g"
  exit 1
fi

result="$(find "${SCRIPT_DIR}/../../" -name '*.yaml' -exec sh -c "grep -H -B1 'egress/enabled:' \$1 | grep -v '\s*#' | grep -v 'egress/enabled:' | awk '{ print \$1 }' | sed 's@-*\$@@g'" shell {} \;)"
if [ -n "${result}" ]; then
  echo "Found enabled egresses without comment:"
  echo "${result}" | awk '{ print "- " $0 }' | sed "s@${SCRIPT_DIR}/../../@./@g"
  exit 1
fi

echo "All good!"
exit 0
