set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

# bootstrap new cluster from scratch
mod bootstrap "bootstrap"
# manage talos cluster
mod talos "talos"
# mod kube "kubernetes"

cluster := shell("cat " + justfile_dir() + "/.current-cluster 2> /dev/null || just cluster")
[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    envconsul -secret="talos/{{ cluster }}" -once -no-prefix minijinja-cli "{{ file }}" {{ args }}

cluster:
  echo -n "$(find "{{ justfile_dir() }}/talos" -mindepth 1 -maxdepth 1 -type d | sed 's@.*/@@g' | xargs gum choose --header 'Cluster?')" > "{{ justfile_dir() }}/.current-cluster"
  cat "{{ justfile_dir() }}/.current-cluster"

