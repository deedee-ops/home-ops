set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

export SECRETSPEC_PROFILE := "xoxo"

# bootstrap new cluster from scratch
mod bootstrap "bootstrap"
# manage talos cluster
mod talos "talos"
# manage kubernetes cluster
mod kube "kubernetes"

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template context file *args:
    envconsul -secret="$CLUSTER/{{ context }}" -once -no-prefix minijinja-cli --strict "{{ file }}" {{ args }} 2> /dev/null
