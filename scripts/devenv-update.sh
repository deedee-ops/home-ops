#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}/.." && devenv update && devenv shell true

# shellcheck disable=SC2044
for profile in $(find "${SCRIPT_DIR}/../.devenv/profiles" -maxdepth 1 -mindepth 1 -type d); do
  attic push nixlab "$(readlink -f "${profile}/profile")"
done
