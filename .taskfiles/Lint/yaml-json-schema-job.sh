#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TMP_DIR="$(mktemp -d)"

# search for manifests without JSON schema links
yaml_files="$(sh -c "find . -name '*.y*ml' -not -name \"$(yq '.ignoreNames|join("\" -not -name \"")' "${SCRIPT_DIR}/../../.yaml-json-schema")\" -not -path ./\"$(yq '.ignorePaths|join("\" -not -path ./\"")' "${SCRIPT_DIR}/../../.yaml-json-schema")\"")"
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
  if ! yq -s '"${TMP_DIR}/test_split_" + $index' "${file}" 2> /dev/null; then
    cp "${file}" "${TMP_DIR}/test_split_0.yml"
  fi
  if grep -Hoc '# yaml-language-serve' "${TMP_DIR}/test_split_"* | grep -q ':0$'; then
    if [ $error == 0 ]; then
      echo "Found YAML files without valid JSON schema manifest links:"
    fi
    error=1
    echo "${file}"
  else
    for split in "${TMP_DIR}/test_split_"*; do
      if [ -z "${IGNORE_SCHEMA_FETCH}" ]; then
        schemaUrl="$(grep '# yaml-language-serve' "${split}" | head -n 1 | awk -F= '{print $2}')"
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
      fi
    done
  fi
  rm -rf "${TMP_DIR}/test_split_"*
done

if [ $error == 1 ]; then
  exit 1
fi

echo "All good!"
exit 0
