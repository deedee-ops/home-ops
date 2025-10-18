set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

cluster := 'meemee'
talos_dir := justfile_dir() + '/talos'
cluster_dir := talos_dir + '/' + cluster

talosctl_cmd := 'talosctl --talosconfig=' + cluster_dir + '/talosconfig'
controller := shell(talosctl_cmd + " config info -o yaml | yq -e '.endpoints[0]'")

[private]
default:
    just -l talos

[doc('Apply Talos config to a node')]
apply-node node *args:
    just talos render-config "{{ node }}" | {{ talosctl_cmd }} -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Download Talos machine image')]
download-image version schematic:
    gum spin --title "Downloading Talos {{ version }} ..." -- \
    curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
        -o "{{ talos_dir }}/talos-{{ version }}-{{ replace_regex(schematic, '^(.{8}).*', '$1') }}.iso" \
        "https://factory.talos.dev/image/{{ schematic }}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "{{ schematic }}"

[doc('Generate schematic ID from Talos schematic')]
gen-schematic-id:
    curl -sX POST --data-binary @<(just template "{{ cluster_dir }}/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'

[doc('Reboot a node')]
reboot-node node:
    gum confirm "Reboot node {{ node }}?" --default="No" && \
        {{ talosctl_cmd }} -n {{ node }} reboot -m powercycle || exit 0

[doc('Render Talos config for a node')]
render-config node:
    export IS_CONTROLPLANE="$(just talos machine-controlplane {{ node }})"; \
    {{ talosctl_cmd }} machineconfig patch <(just template "{{ cluster_dir }}/machineconfig.yaml.j2") \
        -p @<(just template "{{ cluster_dir }}/nodes/{{ node }}.yaml.j2")

[doc('Reset a node')]
reset-node node:
    gum confirm "Reset node {{ node }}?" --default="No" && \
        {{ talosctl_cmd }} -n "{{ node }}" reset --graceful=false || exit 0

[doc('Shutdown a node')]
shutdown-node node:
    gum confirm "Shutdown node {{ node }}?" --default="No" && \
        {{ talosctl_cmd }} -n "{{ node }}" shutdown --force || exit 0

[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    {{ talosctl_cmd }} -n "{{ controller }}" upgrade-k8s --to {{ version }}

[doc('Upgrade Talos version on a node')]
upgrade-node node:
    {{ talosctl_cmd }} -n "{{ node }}" upgrade -i "$(just talos machine-image)" -m powercycle --timeout=10m

[private]
machine-controlplane node:
    just template "{{ cluster_dir }}/nodes/{{ node }}.yaml.j2" | yq -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[private]
machine-image:
    just template "{{ cluster_dir }}/machineconfig.yaml.j2" | yq -e 'select(.machine) | .machine.install.image'
