#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# search for manifests without JSON schema links
yaml_files="$(sh -c "find . -name '*.y*ml' -not -name '*.tmpl.y*ml' -not -name 'values.y*ml' -not -path \"$(yq '.ignore|join("\" -not -path ./\"")' "${SCRIPT_DIR}/../../.yamllint")\"")"
error=0
declare -A CURL_CACHE 2>/dev/null || false
CURL_CACHE["disabled"]="1"

for file in $yaml_files; do
  if [ -n "$*" ]; then
    if [[ "$*" != *"${file//.\//}"* ]]; then
      continue
    fi
  fi
  # shellcheck disable=SC2016
  yq -s '"/tmp/test_split_" + $index' "${file}"
  if grep -Hoc '# yaml-language-serve' /tmp/test_split_* | grep -q ':0$'; then
    if [ $error == 0 ]; then
      echo "Found YAML files without valid JSON schema manifest links:"
    fi
    error=1
    echo "${file}"
  else
    for split in /tmp/test_split_*; do
      schemaUrl="$(grep '# yaml-language-serve' "${split}" | awk -F= '{print $2}')"
      if [ -z "$schemaUrl" ]; then
        schemaUrl="disabled"
      fi

      if [ -z "${CURL_CACHE["$schemaUrl"]}" ]; then
        if ! curl -m 5 -o /dev/null -Ls --fail-with-body "${schemaUrl}"; then
          if [ $error == 0 ]; then
            echo "Found YAML files without valid JSON schema manifest links:"
          fi
          error=1
          echo "${file}: ${schemaUrl}"
        else
          CURL_CACHE["$schemaUrl"]="1"
        fi
      fi
    done
  fi
  rm -rf /tmp/test_split_*
done

if [ $error == 1 ]; then
  exit 1
fi

echo "All good!"
exit 0
