#!/usr/bin/env bash
#
# ansible.cfg points `vault_password_file` at this script. Ansible executes it and
# takes stdout as the vault password, which is how a password held in an environment
# variable reaches ansible-vault - it has no env var of its own for the password,
# only ANSIBLE_VAULT_PASSWORD_FILE for the path.
set -euo pipefail

: "${ANSIBLE_VAULT_PASSWORD:?is not set - export it before running ansible}"

printf '%s\n' "$ANSIBLE_VAULT_PASSWORD"
