#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# search for manifests without JSON schema links
yaml_files="$(sh -c "find . -name '*.y*ml' -not -name '*.tmpl.y*ml' -not -name 'values.y*ml' -not -path \"$(yq '.ignore|join("\" -not -path ./\"")' "${SCRIPT_DIR}/../../.yamllint")\"")"
error=0
for file in $yaml_files; do
  # shellcheck disable=SC2016
  yq -s '"/tmp/test_split_" + $index' "${file}"
  if grep -Hoc yaml-language-serve /tmp/test_split_* | grep -q ':0$'; then
    if [ $error == 0 ]; then
      echo "Found YAML files without JSON schema manifest links:"
    fi
    error=1
    echo "${file}"
  fi
  rm -rf /tmp/test_split_*
done

if [ $error == 1 ]; then
  exit 1
fi

echo "All good!"
exit 0
