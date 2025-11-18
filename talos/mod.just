set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

# cluster := shell("cat " + justfile_dir() + "/.current-cluster 2> /dev/null || just cluster")
cluster := "deedee"

talos_dir := justfile_dir() + '/talos'
cluster_dir := talos_dir + '/' + cluster

controller_cmd := "talosctl --talosconfig=" + cluster_dir + "/talosconfig config info -o yaml | yq -e '.endpoints[0]'"

export TALOSCONFIG := cluster_dir + "/talosconfig"

[private]
default:
    just -l talos

[doc('Apply Talos config to a node')]
apply-node node *args:
    just talos render-config "{{ node }}" | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Download Talos machine image')]
download-image version schematic=shell("just talos gen-schematic-id"):
    gum spin --title "Downloading Talos {{ version }} ..." -- \
    curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
        -o "{{ talos_dir }}/talos-{{ version }}-{{ replace_regex(schematic, '^(.{8}).*', '$1') }}.iso" \
        "https://talos.ajgon.casa/image/{{ schematic }}/v{{ version }}/metal-amd64-secureboot.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "{{ schematic }}"

[doc('Generate schematic ID from Talos schematic')]
gen-schematic-id:
    curl -sX POST --data-binary @<(just template talos "{{ cluster_dir }}/schematic.yaml.j2") "https://talos.ajgon.casa/schematics" | jq -r '.id'

[doc('Reboot a node')]
reboot-node node:
    gum confirm "Reboot node {{ node }}?" --default="No" && \
        talosctl -n {{ node }} reboot -m powercycle || exit 0

[doc('Render Talos config for a node')]
render-config node:
    export IS_CONTROLPLANE="$(just talos machine-controlplane {{ node }})"; \
    talosctl machineconfig patch <(just template talos "{{ cluster_dir }}/machineconfig.yaml.j2") \
        -p @<(just template talos "{{ cluster_dir }}/nodes/{{ node }}.yaml.j2")

[doc('Reset a node')]
reset-node node:
    gum confirm "Reset node {{ node }}?" --default="No" && \
        talosctl -n "{{ node }}" reset --graceful=false || exit 0

[doc('Shutdown a node')]
shutdown-node node:
    gum confirm "Shutdown node {{ node }}?" --default="No" && \
        talosctl -n "{{ node }}" shutdown --force || exit 0

[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl -n "{{ shell(controller_cmd) }}" upgrade-k8s --to {{ version }}

[doc('Upgrade Talos version on a node')]
upgrade-node node:
    talosctl -n "{{ node }}" upgrade -i "$(just talos machine-image)" -m powercycle --timeout=10m

[private]
machine-controlplane node:
    just template talos "{{ cluster_dir }}/nodes/{{ node }}.yaml.j2" | yq -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[private]
machine-image:
    just template talos "{{ cluster_dir }}/machineconfig.yaml.j2" | yq -e 'select(.machine) | .machine.install.image'
