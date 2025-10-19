set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "bootstrap"
#mod kube "kubernetes"
mod talos "talos"

cluster := shell("cat " + justfile_dir() + "/.current-cluster 2> /dev/null || just cluster")

cluster:
  echo -n "$(find "{{ justfile_dir() }}/talos" -mindepth 1 -maxdepth 1 -type d | sed 's@.*/@@g' | xargs gum choose --header 'Cluster?')" > "{{ justfile_dir() }}/.current-cluster"
  cat "{{ justfile_dir() }}/.current-cluster"

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file $CLUSTER_NAME=cluster *args:
    minijinja-cli "{{ file }}" {{ args }} | op inject
