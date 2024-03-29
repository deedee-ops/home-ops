#!/usr/bin/env bash

set -o pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# validate all helm template with kubeconform
helm_templates="$(find "${SCRIPT_DIR}/../../kubernetes/apps" -mindepth 2 -maxdepth 2 -type d | sort)"
error=0

for helm in ${helm_templates}; do
  if [ -f "${helm}/.kubeconformignore" ]; then
    continue
  fi
  if ! helm dependency update "${helm}" > /dev/null 2>&1; then
    if [ $error == 0 ]; then
      echo "Found helm templates not passing kubeconform test"
    fi

    # shellcheck disable=SC2001
    echo "${helm} (helm dependency build)" | sed 's@.*\.\./@@g'
    error=1
    continue
  fi

  sed 's@<path:kubernetes.*>@test@g' "${helm}/values.yaml" > /tmp/kubeconform-values.yaml
  if ! (helm template "${helm}" -f /tmp/kubeconform-values.yaml 2>/tmp/kubeconform | kubeconform -schema-location default -schema-location 'https://deedee-ops.github.io/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' -ignore-missing-schemas -strict -exit-on-error -skip CiliumNetworkPolicy,CiliumClusterwideNetworkPolicy > /tmp/kubeconform 2>&1); then
    if [ $error == 0 ]; then
      echo "Found helm templates not passing kubeconform test"
    fi

    # shellcheck disable=SC2001
    echo "${helm} (kubeconform)" | sed 's@.*\.\./@@g'
    cat /tmp/kubeconform
    error=1
  fi
  rm -rf /tmp/kubeconform-values.yaml || true
done

if [ $error == 1 ]; then
  exit 1
fi

echo "All good!"
exit 0
