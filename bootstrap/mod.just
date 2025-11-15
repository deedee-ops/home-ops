set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

export CLUSTER := shell("cat " + justfile_dir() + "/.current-cluster 2> /dev/null || just cluster")
export TALOSCONFIG := cluster_dir + "/talosconfig"
export KUBECONFIG := cluster_dir + "/kubeconfig"

bootstrap_dir := justfile_dir() + '/bootstrap'
kubernetes_dir := justfile_dir() + '/kubernetes'
talos_dir := justfile_dir() + '/talos'
cluster_dir := talos_dir + '/' + CLUSTER

kubectl_cmd := 'kubectl --kubeconfig=' + cluster_dir + '/kubeconfig'
controller_cmd := "talosctl --talosconfig=" + cluster_dir + "/talosconfig config info -o yaml | yq -e '.endpoints[0]'"
nodes_cmd := "talosctl --talosconfig=" + cluster_dir + "/talosconfig config info -o yaml | yq -e '.nodes | join (\" \")'"

[private]
default: talos k8s (kubeconfig "node") wait namespaces resources crds apps kubeconfig

[doc('Install Talos')]
talos:
    just log info "Running stage..." "stage" "$0"
    for n in {{ shell(nodes_cmd) }}; do \
        if ! op=$(just talos apply-node "$n" --insecure 2>&1); then \
            if [[ "$op" == *"certificate required"* ]]; then \
                just log info "Talos already configured, skipping apply of config" "stage" "$0" "node" "$n"; \
                continue; \
            fi; \
            just log fatal "Failed to apply Talos configuration" "stage" "$0" "node" "$n" "output" "$op"; \
        fi; \
    done

[doc('Install Kubernetes')]
k8s:
    just log info "Running stage..." "stage" "$0"
    until op=$(talosctl -n "{{ shell(controller_cmd) }}" bootstrap 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do \
        just log info "Kubernetes bootstrap in progress. Retrying in 5 seconds..." "stage" "$0"; \
        sleep 5; \
    done

[doc('Fetch kubeconfig')]
kubeconfig lb="cilium":
    just log info "Running stage..." "stage" "$0"
    if ! talosctl kubeconfig -n "{{ shell(controller_cmd) }}" -f --force-context-name $CLUSTER $KUBECONFIG; then \
        just log fatal "Failed to fetch kubeconfig" "stage" "$0"; \
    fi
    if [[ "{{ lb }}" != "cilium" ]]; then \
        if ! kubectl config set-cluster $CLUSTER --server "https://{{ shell(controller_cmd) }}:6443"; then \
            just log fatal "Failed to set kubectl cluster server address" "stage" "$0"; \
        fi; \
    fi

[doc('Wait for nodes to be not-ready')]
wait:
    just log info "Running stage..." "stage" "$0"
    if ! {{ kubectl_cmd }} wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then \
        until {{ kubectl_cmd }} wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do \
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "$0"; \
            sleep 5; \
        done \
    fi

[doc('Apply Kubernetes namespaces')]
namespaces:
    just log info "Running stage..." "stage" "$0"
    find "{{ kubernetes_dir }}/clusters/$CLUSTER/apps" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r dir; do \
        if ! kustomize build "$dir" | yq ea -e 'select(.kind == "Namespace")' | kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -; then \
            just log fatal "Failed to apply namespace" "stage" "$0" "namespace" "$(basename "$dir")"; \
        fi; \
    done

[doc('Apply Kubernetes resources')]
resources:
    just log info "Running stage..." "stage" "$0"
    if ! just template kubernetes "{{ bootstrap_dir }}/resources.yaml.j2" | {{ kubectl_cmd }} apply --server-side --field-manager bootstrap --force-conflicts -f -; then \
        just log fatal "Failed to apply resources" "stage" "$0"; \
    fi;

[doc('Apply Helmfile CRDs')]
crds:
    just log info "Running stage..." "stage" "$0"
    if ! helmfile -f "{{ bootstrap_dir }}/helmfile.d/00-crds.yaml" template -q | {{ kubectl_cmd }} apply --server-side --field-manager bootstrap --force-conflicts -f -; then \
        just log fatal "Failed to apply crds" "stage" "$0"; \
    fi;

[doc('Apply Helmfile Apps')]
apps:
    just log info "Running stage..." "stage" "$0"
    if ! helmfile -f "{{ bootstrap_dir }}/helmfile.d/01-apps.yaml" sync --hide-notes; then \
        just log fatal "Failed to sync helmfile" "stage" "$0"; \
    fi
